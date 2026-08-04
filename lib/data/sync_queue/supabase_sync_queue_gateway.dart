import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_queue_item.dart';
import 'sync_queue_remote_gateway.dart';

class SupabaseSyncQueueGateway implements SyncQueueRemoteGateway {
  const SupabaseSyncQueueGateway(this._client);

  static const String localLogoPathKey = '_local_logo_path';

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
    if (localLogoPath != null && localLogoPath.isNotEmpty) {
      payload['logo_url'] = await _uploadQueuedLogo(
        item: item,
        localPath: localLogoPath,
      );
    }

    Object? response;
    try {
      response = await _client.rpc(
        'process_directory_sync_operation',
        params: {
          'p_operation_id': item.id,
          'p_entity_type': item.entityType.databaseValue,
          'p_operation_type': item.operationType.databaseValue,
          'p_entity_id': item.entityId,
          'p_payload': payload,
        },
      );
    } on PostgrestException catch (error) {
      const permanentCodes = <String>{
        '22023',
        '22P02',
        '23503',
        '23505',
        '42501',
      };
      throw SyncQueueExecutionException(
        message: error.message,
        code: error.code,
        isRetryable: !permanentCodes.contains(error.code),
        cause: error,
      );
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

  Future<String> _uploadQueuedLogo({
    required SyncQueueItem item,
    required String localPath,
  }) async {
    final entityId = item.entityId;
    if (entityId == null || entityId.trim().isEmpty) {
      throw const SyncQueueExecutionException(
        message: 'A business ID is required to upload the queued logo.',
        code: '22023',
        isRetryable: false,
      );
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw const SyncQueueExecutionException(
        message: 'The locally selected business image no longer exists.',
        code: 'LOCAL_FILE_MISSING',
        isRetryable: false,
      );
    }

    final extension = _safeImageExtension(localPath);
    final safeOperationId = item.id.replaceAll(
      RegExp('[^a-zA-Z0-9_-]'),
      '_',
    );
    final storagePath = '$entityId/queued_$safeOperationId.$extension';

    try {
      await _client.storage.from('business-media').upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: _contentTypeFor(extension),
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

    return _client.storage.from('business-media').getPublicUrl(storagePath);
  }

  String _safeImageExtension(String path) {
    final match = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(path);
    final extension = match?.group(1)?.toLowerCase();
    return switch (extension) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
  }

  String _contentTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
