import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_queue_item.dart';
import 'sync_queue_remote_gateway.dart';

class SupabaseSyncQueueGateway implements SyncQueueRemoteGateway {
  const SupabaseSyncQueueGateway(this._client);

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

    Object? response;
    try {
      response = await _client.rpc(
        'process_directory_sync_operation',
        params: {
          'p_operation_id': item.id,
          'p_entity_type': item.entityType.databaseValue,
          'p_operation_type': item.operationType.databaseValue,
          'p_entity_id': item.entityId,
          'p_payload': item.payload,
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
}
