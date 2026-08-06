import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/media_upload_service.dart';
import '../../core/services/supabase_service.dart';
import '../../models/business_gallery_image.dart';

class BusinessGalleryRepositoryFailure implements Exception {
  const BusinessGalleryRepositoryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class BusinessGalleryRepository {
  BusinessGalleryRepository({
    SupabaseClient? client,
    MediaUploadService? mediaService,
  })  : _client = client,
        _mediaService = mediaService ?? MediaUploadService(client: client);

  final SupabaseClient? _client;
  final MediaUploadService _mediaService;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<List<BusinessGalleryImage>> loadGallery(String businessId) async {
    final id = businessId.trim();
    if (id.isEmpty) {
      return const <BusinessGalleryImage>[];
    }

    try {
      final rows = await _supabase
          .from('business_images')
          .select(
            'id, business_id, storage_path, public_url, alt_text, '
            'sort_order, is_primary, created_at, updated_at, deleted_at, '
            'sync_version',
          )
          .eq('business_id', id)
          .isFilter('deleted_at', null)
          .order('is_primary', ascending: false)
          .order('sort_order');
      return BusinessGalleryImage.readList(rows);
    } on PostgrestException catch (error) {
      throw BusinessGalleryRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<List<BusinessGalleryImage>> pickAndAddImage({
    required String businessId,
    String altText = '',
    bool makePrimary = false,
    ValueChanged<double>? onProgress,
  }) async {
    final id = businessId.trim();
    if (id.isEmpty) {
      throw const BusinessGalleryRepositoryFailure(
        'احفظ النشاط أولًا قبل إضافة صور المعرض.',
      );
    }

    final upload = await _mediaService.pickAndUpload(
      kind: MediaAssetKind.businessGallery,
      entityId: id,
      onProgress: onProgress,
    );
    if (upload == null) {
      return loadGallery(id);
    }

    try {
      return await addUploadedImage(
        businessId: id,
        upload: upload,
        altText: altText,
        makePrimary: makePrimary,
      );
    } catch (_) {
      try {
        await _mediaService.deleteAsset(
          kind: MediaAssetKind.businessGallery,
          value: upload.storagePath,
        );
      } catch (_) {
        // The database mutation failed. Storage cleanup remains best effort.
      }
      rethrow;
    }
  }

  Future<List<BusinessGalleryImage>> addUploadedImage({
    required String businessId,
    required MediaUploadResult upload,
    String altText = '',
    bool makePrimary = false,
  }) {
    return _manage(
      businessId: businessId,
      action: 'add',
      storagePath: upload.storagePath,
      publicUrl: upload.publicUrl,
      altText: altText,
      makePrimary: makePrimary,
    );
  }

  Future<List<BusinessGalleryImage>> setPrimary({
    required String businessId,
    required String imageId,
  }) {
    return _manage(
      businessId: businessId,
      action: 'primary',
      imageId: imageId,
    );
  }

  Future<List<BusinessGalleryImage>> updateAltText({
    required String businessId,
    required String imageId,
    required String altText,
  }) {
    return _manage(
      businessId: businessId,
      action: 'alt',
      imageId: imageId,
      altText: altText,
    );
  }

  Future<List<BusinessGalleryImage>> pickAndReplaceImage({
    required String businessId,
    required BusinessGalleryImage image,
    ValueChanged<double>? onProgress,
  }) async {
    final upload = await _mediaService.pickAndUpload(
      kind: MediaAssetKind.businessGallery,
      entityId: businessId,
      onProgress: onProgress,
    );
    if (upload == null) {
      return loadGallery(businessId);
    }

    try {
      final images = await _manage(
        businessId: businessId,
        action: 'replace',
        imageId: image.id,
        storagePath: upload.storagePath,
        publicUrl: upload.publicUrl,
        altText: image.altText,
      );
      try {
        await _mediaService.deleteAsset(
          kind: MediaAssetKind.businessGallery,
          value: image.storagePath,
        );
      } catch (_) {
        // The old object can be retried by the administrator orphan cleaner.
      }
      return images;
    } catch (_) {
      try {
        await _mediaService.deleteAsset(
          kind: MediaAssetKind.businessGallery,
          value: upload.storagePath,
        );
      } catch (_) {
        // The new object remains an orphan candidate when cleanup fails.
      }
      rethrow;
    }
  }

  Future<List<BusinessGalleryImage>> reorder({
    required String businessId,
    required List<String> orderedImageIds,
  }) {
    return _manage(
      businessId: businessId,
      action: 'reorder',
      orderedImageIds: orderedImageIds,
    );
  }

  Future<List<BusinessGalleryImage>> deleteImage({
    required String businessId,
    required BusinessGalleryImage image,
  }) async {
    final images = await _manage(
      businessId: businessId,
      action: 'delete',
      imageId: image.id,
    );
    try {
      await _mediaService.deleteAsset(
        kind: MediaAssetKind.businessGallery,
        value: image.storagePath,
      );
    } catch (_) {
      // Metadata is already removed. The admin orphan cleaner can retry later.
    }
    return images;
  }

  Future<List<BusinessGalleryImage>> _manage({
    required String businessId,
    required String action,
    String? imageId,
    String? storagePath,
    String? publicUrl,
    String? altText,
    bool makePrimary = false,
    List<String>? orderedImageIds,
  }) async {
    try {
      final response = await _supabase.rpc(
        'manage_business_gallery',
        params: <String, dynamic>{
          'p_business_id': businessId.trim(),
          'p_action': action,
          'p_image_id': _nullable(imageId),
          'p_storage_path': _nullable(storagePath),
          'p_public_url': _nullable(publicUrl),
          'p_alt_text': altText?.trim() ?? '',
          'p_make_primary': makePrimary,
          'p_ordered_ids': orderedImageIds,
        },
      );
      final data = _asMap(response);
      return BusinessGalleryImage.readList(data['gallery']);
    } on PostgrestException catch (error) {
      throw BusinessGalleryRepositoryFailure(_friendlyMessage(error));
    }
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    throw const BusinessGalleryRepositoryFailure(
      'أعاد الخادم نتيجة غير صالحة لمعرض الصور.',
    );
  }

  static String? _nullable(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _friendlyMessage(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (error.code == '42501' || message.contains('permission')) {
      return 'لا تملك صلاحية تعديل صور هذا النشاط.';
    }
    if (message.contains('maximum') || message.contains('five')) {
      return 'الحد الأقصى لمعرض النشاط هو 5 صور.';
    }
    if (error.code == 'P0002' || message.contains('not found')) {
      return 'تعذر العثور على النشاط أو صورة المعرض.';
    }
    if (error.code == '22023') {
      return error.message;
    }
    return 'تعذر تحديث معرض الصور. تحقق من الاتصال ثم أعد المحاولة.';
  }
}
