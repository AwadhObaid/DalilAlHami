import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/media_upload_service.dart';
import 'sync_queue_item.dart';
import 'sync_queue_remote_gateway.dart';

class SupabaseSyncQueueGateway implements SyncQueueRemoteGateway {
  const SupabaseSyncQueueGateway(this._client);

  static const String localLogoPathKey = '_local_logo_path';
  static const String localGalleryPathsKey = '_local_gallery_paths';

  final SupabaseClient _client;

  @override
  Future<SyncQueueRemoteResult> execute(SyncQueueItem item) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw StateError(
        'A signed-in Supabase user is required to process the sync queue.',
      );
    }
    if (currentUser.id != item.userId) {
      throw StateError(
        'The queued operation belongs to a different user.',
      );
    }

    final payload = Map<String, dynamic>.from(item.payload);
    final localLogoPath = payload.remove(localLogoPathKey)?.toString().trim();
    final localGalleryPaths = _readPathList(
      payload.remove(localGalleryPathsKey),
    );

    final hasLocationPayload =
        payload.containsKey('latitude') || payload.containsKey('longitude');
    final result = await _executeDirectoryOperation(item, payload);
    if (result.isConflict ||
        item.operationType == SyncQueueOperationType.deleteEntity) {
      return result;
    }

    final remoteEntityId = result.entityId?.trim() ?? '';
    final businessId = remoteEntityId.isNotEmpty
        ? remoteEntityId
        : item.entityId?.trim() ?? '';
    if (businessId.isEmpty) {
      throw const SyncQueueExecutionException(
        message: 'A business ID is required to finalize queued data.',
        code: '22023',
        isRetryable: false,
      );
    }

    if (hasLocationPayload) {
      await _applyOwnedBusinessLocation(
        businessId: businessId,
        latitude: payload['latitude'],
        longitude: payload['longitude'],
      );
    }

    if ((localLogoPath == null || localLogoPath.isEmpty) &&
        localGalleryPaths.isEmpty) {
      return result;
    }

    String? logoUrl;
    if (localLogoPath != null && localLogoPath.isNotEmpty) {
      final upload = await _uploadQueuedImage(
        item: item,
        businessId: businessId,
        localPath: localLogoPath,
        kind: MediaAssetKind.businessLogo,
        suffix: 'logo',
      );
      logoUrl = upload.publicUrl;
    }

    final gallery = <Map<String, dynamic>>[];
    for (var index = 0;
        index < localGalleryPaths.length && index < 5;
        index++) {
      final upload = await _uploadQueuedImage(
        item: item,
        businessId: businessId,
        localPath: localGalleryPaths[index],
        kind: MediaAssetKind.businessGallery,
        suffix: 'gallery_$index',
      );
      gallery.add(<String, dynamic>{
        'storage_path': upload.storagePath,
        'public_url': upload.publicUrl,
        'alt_text': '',
        'sort_order': index,
        'is_primary': index == 0,
      });
    }

    try {
      await _client.rpc(
        'finalize_owner_business_media',
        params: <String, dynamic>{
          'p_business_id': businessId,
          'p_logo_url': logoUrl,
          'p_gallery': gallery,
        },
      );
    } on PostgrestException catch (error) {
      throw _postgrestFailure(error);
    }

    return result;
  }

  Future<SyncQueueRemoteResult> _executeDirectoryOperation(
    SyncQueueItem item,
    Map<String, dynamic> payload,
  ) async {
    Object? response;
    try {
      final rpcName = payload.containsKey('contact_numbers')
          ? 'process_directory_sync_operation_v2'
          : 'process_directory_sync_operation';
      response = await _client.rpc(
        rpcName,
        params: <String, dynamic>{
          'p_operation_id': item.id,
          'p_entity_type': item.entityType.databaseValue,
          'p_operation_type': item.operationType.databaseValue,
          'p_entity_id': item.entityId,
          'p_payload': payload,
        },
      );
    } on PostgrestException catch (error) {
      throw _postgrestFailure(error);
    }

    final result = SyncQueueRemoteResult.fromRpc(response);
    if (result.operationId != item.id) {
      throw const FormatException(
        'Supabase returned a different sync operation ID.',
      );
    }
    if (result.operationType != item.operationType.databaseValue) {
      throw const FormatException(
        'Supabase returned a different sync operation type.',
      );
    }
    return result;
  }

  Future<void> _applyOwnedBusinessLocation({
    required String businessId,
    required Object? latitude,
    required Object? longitude,
  }) async {
    try {
      await _client.rpc(
        'owner_set_business_location',
        params: <String, dynamic>{
          'p_business_id': businessId,
          'p_latitude': latitude,
          'p_longitude': longitude,
        },
      );
    } on PostgrestException catch (error) {
      throw _postgrestFailure(error);
    }
  }

  Future<MediaUploadResult> _uploadQueuedImage({
    required SyncQueueItem item,
    required String businessId,
    required String localPath,
    required MediaAssetKind kind,
    required String suffix,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw const SyncQueueExecutionException(
        message: 'A locally selected business image no longer exists.',
        code: 'LOCAL_FILE_MISSING',
        isRetryable: false,
      );
    }

    PreparedMediaImage prepared;
    try {
      prepared = MediaImageProcessor.prepare(
        await file.readAsBytes(),
        kind,
      );
    } on MediaUploadException catch (error) {
      throw SyncQueueExecutionException(
        message: error.message,
        code: 'LOCAL_IMAGE_INVALID',
        isRetryable: false,
        cause: error,
      );
    }

    final safeOperationId = item.id.replaceAll(
      RegExp('[^a-zA-Z0-9_-]'),
      '_',
    );
    final storagePath = '$businessId/queued_${safeOperationId}_$suffix.jpg';

    try {
      await _client.storage.from('business-media').uploadBinary(
            storagePath,
            prepared.bytes,
            fileOptions: const FileOptions(
              cacheControl: '31536000',
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );
    } on StorageException catch (error) {
      final message = error.toString().toLowerCase();
      final alreadyExists = message.contains('409') ||
          message.contains('already exists') ||
          message.contains('duplicate');
      if (!alreadyExists) {
        rethrow;
      }
    }

    return MediaUploadResult(
      publicUrl:
          _client.storage.from('business-media').getPublicUrl(storagePath),
      storagePath: storagePath,
      width: prepared.width,
      height: prepared.height,
      originalBytes: prepared.originalBytes,
      uploadedBytes: prepared.bytes.lengthInBytes,
    );
  }

  static List<String> _readPathList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(
      value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .take(5),
    );
  }

  static SyncQueueExecutionException _postgrestFailure(
    PostgrestException error,
  ) {
    const permanentCodes = <String>{
      '22023',
      '22P02',
      '23503',
      '23505',
      '42501',
    };
    return SyncQueueExecutionException(
      message: error.message,
      code: error.code,
      isRetryable: !permanentCodes.contains(error.code),
      cause: error,
    );
  }
}
