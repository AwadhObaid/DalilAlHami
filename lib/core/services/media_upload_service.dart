import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

enum MediaAssetKind {
  profileAvatar(
    bucket: 'avatars',
    fileStem: 'avatar',
    maxWidth: 1024,
    maxHeight: 1024,
    quality: 86,
  ),
  category(
    bucket: 'category-media',
    fileStem: 'category',
    maxWidth: 1200,
    maxHeight: 1200,
    quality: 84,
  ),
  businessLogo(
    bucket: 'business-media',
    fileStem: 'logo',
    maxWidth: 1024,
    maxHeight: 1024,
    quality: 86,
  ),
  businessCover(
    bucket: 'business-media',
    fileStem: 'cover',
    maxWidth: 1600,
    maxHeight: 900,
    quality: 84,
  ),
  businessGallery(
    bucket: 'business-media',
    fileStem: 'gallery',
    maxWidth: 1600,
    maxHeight: 1200,
    quality: 84,
  ),
  advertisementExpanded(
    bucket: 'advertisements',
    fileStem: 'expanded',
    maxWidth: 1440,
    maxHeight: 810,
    quality: 86,
  ),
  advertisementCompact(
    bucket: 'advertisements',
    fileStem: 'compact',
    maxWidth: 1600,
    maxHeight: 360,
    quality: 86,
  );

  const MediaAssetKind({
    required this.bucket,
    required this.fileStem,
    required this.maxWidth,
    required this.maxHeight,
    required this.quality,
  });

  final String bucket;
  final String fileStem;
  final int maxWidth;
  final int maxHeight;
  final int quality;
}

class PreparedMediaImage {
  const PreparedMediaImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.originalBytes,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int originalBytes;
}

class MediaUploadResult {
  const MediaUploadResult({
    required this.publicUrl,
    required this.storagePath,
    required this.width,
    required this.height,
    required this.originalBytes,
    required this.uploadedBytes,
  });

  final String publicUrl;
  final String storagePath;
  final int width;
  final int height;
  final int originalBytes;
  final int uploadedBytes;

  double get compressionRatio =>
      originalBytes <= 0 ? 1 : uploadedBytes / originalBytes;
}

class MediaUploadException implements Exception {
  const MediaUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MediaImageProcessor {
  const MediaImageProcessor._();

  static PreparedMediaImage prepare(
    Uint8List source,
    MediaAssetKind kind,
  ) {
    final decoded = img.decodeImage(source);
    if (decoded == null) {
      throw const MediaUploadException(
        'تعذر قراءة الصورة. اختر ملف JPG أو PNG أو WEBP صالحًا.',
      );
    }

    final oriented = img.bakeOrientation(decoded);
    final target = _fitInside(
      width: oriented.width,
      height: oriented.height,
      maxWidth: kind.maxWidth,
      maxHeight: kind.maxHeight,
    );
    final resized =
        target.width == oriented.width && target.height == oriented.height
            ? oriented
            : img.copyResize(
                oriented,
                width: target.width,
                height: target.height,
                interpolation: img.Interpolation.average,
              );
    final encoded = Uint8List.fromList(
      img.encodeJpg(resized, quality: kind.quality),
    );

    return PreparedMediaImage(
      bytes: encoded,
      width: resized.width,
      height: resized.height,
      originalBytes: source.lengthInBytes,
    );
  }

  static ({int width, int height}) _fitInside({
    required int width,
    required int height,
    required int maxWidth,
    required int maxHeight,
  }) {
    if (width <= maxWidth && height <= maxHeight) {
      return (width: width, height: height);
    }

    final scale = (maxWidth / width) < (maxHeight / height)
        ? maxWidth / width
        : maxHeight / height;
    return (
      width: (width * scale).round().clamp(1, maxWidth).toInt(),
      height: (height * scale).round().clamp(1, maxHeight).toInt(),
    );
  }
}

class MediaUploadService {
  MediaUploadService({
    SupabaseClient? client,
    ImagePicker? picker,
  })  : _client = client,
        _picker = picker ?? ImagePicker();

  final SupabaseClient? _client;
  final ImagePicker _picker;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<MediaUploadResult?> pickAndUpload({
    required MediaAssetKind kind,
    required String entityId,
    String? previousValue,
    ValueChanged<double>? onProgress,
    ImageSource source = ImageSource.gallery,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 100,
      requestFullMetadata: false,
    );
    if (picked == null) {
      return null;
    }

    onProgress?.call(0.08);
    final sourceBytes = await picked.readAsBytes();
    if (sourceBytes.isEmpty) {
      throw const MediaUploadException('ملف الصورة فارغ.');
    }
    if (sourceBytes.lengthInBytes > 15 * 1024 * 1024) {
      throw const MediaUploadException(
        'حجم الصورة الأصلية يتجاوز 15 ميجابايت.',
      );
    }

    onProgress?.call(0.28);
    final prepared = await compute(
      _prepareMediaInIsolate,
      _MediaPrepareRequest(sourceBytes, kind),
    );
    onProgress?.call(0.55);

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const MediaUploadException(
        'انتهت جلسة الدخول. سجل الدخول ثم أعد رفع الصورة.',
      );
    }

    final path = buildStoragePath(
      kind: kind,
      entityId: entityId,
      userId: userId,
      timestamp: DateTime.now().toUtc(),
    );

    try {
      await _supabase.storage.from(kind.bucket).uploadBinary(
            path,
            prepared.bytes,
            fileOptions: const FileOptions(
              cacheControl: '31536000',
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      onProgress?.call(0.9);

      final publicUrl = _supabase.storage.from(kind.bucket).getPublicUrl(path);
      await _removePreviousIfOwned(
        kind: kind,
        previousValue: previousValue,
        replacementPath: path,
      );
      onProgress?.call(1);

      return MediaUploadResult(
        publicUrl: publicUrl,
        storagePath: path,
        width: prepared.width,
        height: prepared.height,
        originalBytes: prepared.originalBytes,
        uploadedBytes: prepared.bytes.lengthInBytes,
      );
    } on StorageException catch (error) {
      throw MediaUploadException(_friendlyStorageMessage(error));
    }
  }

  Future<MediaUploadResult> moveDraftAssetToBusiness({
    required MediaAssetKind kind,
    required String value,
    required String businessId,
    ValueChanged<double>? onProgress,
  }) async {
    if (kind.bucket != 'business-media') {
      throw const MediaUploadException(
        'نقل ملفات المسودة متاح لصور الأنشطة فقط.',
      );
    }

    final sourcePath = storagePathFromValue(value, bucket: kind.bucket);
    if (sourcePath == null) {
      throw const MediaUploadException('مسار صورة المسودة غير صالح.');
    }
    if (!sourcePath.startsWith('drafts/')) {
      final publicUrl = resolvePublicValue(
        value: value,
        bucket: kind.bucket,
        client: _supabase,
      );
      return MediaUploadResult(
        publicUrl: publicUrl,
        storagePath: sourcePath,
        width: 0,
        height: 0,
        originalBytes: 0,
        uploadedBytes: 0,
      );
    }

    final safeBusinessId = sanitizePathSegment(businessId);
    if (safeBusinessId.isEmpty || safeBusinessId == 'new') {
      throw const MediaUploadException('معرف النشاط غير صالح لنقل الصورة.');
    }

    final extension = sourcePath.toLowerCase().endsWith('.png')
        ? 'png'
        : sourcePath.toLowerCase().endsWith('.webp')
            ? 'webp'
            : 'jpg';
    final destination = '$safeBusinessId/${kind.fileStem}-'
        '${DateTime.now().toUtc().microsecondsSinceEpoch}.$extension';

    try {
      onProgress?.call(0.2);
      await _supabase.storage.from(kind.bucket).move(
            sourcePath,
            destination,
          );
      onProgress?.call(0.9);
      final publicUrl =
          _supabase.storage.from(kind.bucket).getPublicUrl(destination);
      onProgress?.call(1);
      return MediaUploadResult(
        publicUrl: publicUrl,
        storagePath: destination,
        width: 0,
        height: 0,
        originalBytes: 0,
        uploadedBytes: 0,
      );
    } on StorageException catch (error) {
      throw MediaUploadException(_friendlyStorageMessage(error));
    }
  }

  static bool isDraftBusinessMedia(String? value) {
    final path = storagePathFromValue(value, bucket: 'business-media');
    return path != null && path.startsWith('drafts/');
  }

  Future<void> deleteAsset({
    required MediaAssetKind kind,
    required String value,
  }) async {
    final path = storagePathFromValue(value, bucket: kind.bucket);
    if (path == null) {
      return;
    }

    try {
      await _supabase.storage.from(kind.bucket).remove(<String>[path]);
    } on StorageException catch (error) {
      throw MediaUploadException(_friendlyStorageMessage(error));
    }
  }

  Future<void> _removePreviousIfOwned({
    required MediaAssetKind kind,
    required String? previousValue,
    required String replacementPath,
  }) async {
    final previousPath = storagePathFromValue(
      previousValue,
      bucket: kind.bucket,
    );
    if (previousPath == null || previousPath == replacementPath) {
      return;
    }

    try {
      await _supabase.storage.from(kind.bucket).remove(<String>[previousPath]);
    } on StorageException {
      // The new upload is already valid. Old-object cleanup is best effort and
      // can be retried by the server-side orphan cleanup job.
    }
  }

  static String buildStoragePath({
    required MediaAssetKind kind,
    required String entityId,
    required String userId,
    required DateTime timestamp,
  }) {
    final safeEntity = sanitizePathSegment(entityId);
    final safeUser = sanitizePathSegment(userId);
    final stamp = timestamp.microsecondsSinceEpoch;

    if (kind == MediaAssetKind.profileAvatar) {
      return '$safeUser/${kind.fileStem}-$stamp.jpg';
    }

    if (kind == MediaAssetKind.businessLogo ||
        kind == MediaAssetKind.businessCover ||
        kind == MediaAssetKind.businessGallery) {
      if (safeEntity.isNotEmpty && safeEntity != 'new') {
        return '$safeEntity/${kind.fileStem}-$stamp.jpg';
      }
      return 'drafts/$safeUser/${kind.fileStem}-$stamp.jpg';
    }

    final folder =
        safeEntity.isEmpty || safeEntity == 'new' ? 'drafts' : safeEntity;
    return '$safeUser/$folder/${kind.fileStem}-$stamp.jpg';
  }

  static String sanitizePathSegment(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static String? storagePathFromValue(
    String? value, {
    required String bucket,
  }) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(text);
    if (uri != null && uri.hasScheme) {
      final marker = '/storage/v1/object/public/$bucket/';
      final index = uri.path.indexOf(marker);
      if (index < 0) {
        return null;
      }
      final encodedPath = uri.path.substring(index + marker.length);
      return Uri.decodeComponent(encodedPath);
    }

    return text.startsWith('/') ? text.substring(1) : text;
  }

  static String resolvePublicValue({
    required String? value,
    required String bucket,
    SupabaseClient? client,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(text);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return text;
    }
    if (client == null && !SupabaseService.isInitialized) {
      return '';
    }
    final supabase = client ?? SupabaseService.client;
    return supabase.storage.from(bucket).getPublicUrl(
          text.startsWith('/') ? text.substring(1) : text,
        );
  }

  static String _friendlyStorageMessage(StorageException error) {
    final message = error.message.toLowerCase();
    if (message.contains('row-level security') ||
        message.contains('unauthorized') ||
        message.contains('forbidden')) {
      return 'لا تسمح صلاحيات التخزين الحالية برفع هذه الصورة.';
    }
    if (message.contains('payload') || message.contains('size')) {
      return 'حجم الصورة أكبر من الحد المسموح به.';
    }
    if (message.contains('mime') || message.contains('content type')) {
      return 'صيغة الصورة غير مسموح بها.';
    }
    return 'تعذر رفع الصورة إلى التخزين. تحقق من الاتصال ثم أعد المحاولة.';
  }
}

class _MediaPrepareRequest {
  const _MediaPrepareRequest(this.bytes, this.kind);

  final Uint8List bytes;
  final MediaAssetKind kind;
}

PreparedMediaImage _prepareMediaInIsolate(_MediaPrepareRequest request) {
  return MediaImageProcessor.prepare(request.bytes, request.kind);
}
