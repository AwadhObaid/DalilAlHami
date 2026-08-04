import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_item.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_processor.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_remote_gateway.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalDirectoryDatabase database;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    database = LocalDirectoryDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('processor immediately recovers work interrupted by app shutdown',
      () async {
    await database.initializeWithSeedData();
    final now = DateTime.utc(2026, 8, 4, 20);

    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-recovery',
        operationId: 'operation-recovery',
        deduplicationKey: 'operation-recovery',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-recovery',
        operationType: SyncQueueOperationType.update,
        payload: const <String, dynamic>{'name': 'Recovered'},
        createdAt: now,
      ),
    );

    final claimed = await database.claimSyncOperation(
      'operation-recovery',
      userId: 'user-recovery',
      now: now,
    );
    expect(claimed, isNotNull);
    expect(claimed!.status, SyncQueueStatus.processing);

    final gateway = _SuccessfulRecoveryGateway();
    final processor = SyncQueueProcessor(
      database: database,
      gateway: gateway,
      userId: 'user-recovery',
      clock: () => now,
    );

    final report = await processor.processPending();
    final summary = await database.readSyncQueueSummary(
      userId: 'user-recovery',
    );

    expect(report.completed, 1);
    expect(gateway.calls, 1);
    expect(summary.completed, 1);
    expect(summary.processing, 0);
  });
}

class _SuccessfulRecoveryGateway implements SyncQueueRemoteGateway {
  var calls = 0;

  @override
  Future<SyncQueueRemoteResult> execute(SyncQueueItem item) async {
    calls++;
    return SyncQueueRemoteResult(
      operationId: item.id,
      operationType: item.operationType.databaseValue,
      entityId: item.entityId,
      remoteStatus: 'pending',
      raw: <String, dynamic>{
        'operation_id': item.id,
        'operation_type': item.operationType.databaseValue,
        'entity_id': item.entityId,
        'remote_status': 'pending',
        'replayed': false,
      },
    );
  }
}
