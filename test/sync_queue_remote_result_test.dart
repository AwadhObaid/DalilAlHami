import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_remote_gateway.dart';

void main() {
  test('يحوّل استجابة Supabase وإشارة replayed بصورة صحيحة', () {
    final result = SyncQueueRemoteResult.fromRpc(const {
      'operation_id': 'operation-001',
      'operation_type': 'update',
      'entity_id': 'business-001',
      'remote_status': 'pending',
      'replayed': true,
    });

    expect(result.operationId, 'operation-001');
    expect(result.entityId, 'business-001');
    expect(result.remoteStatus, 'pending');
    expect(result.replayed, isTrue);
  });
}
