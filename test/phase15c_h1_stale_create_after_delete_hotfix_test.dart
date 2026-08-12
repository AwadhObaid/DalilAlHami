import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_item.dart';
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
  tearDown(() async => database.close());

  test('completed delete purges an exhausted stale create', () async {
    await database.initializeWithSeedData();
    final createdAt = DateTime.utc(2026, 8, 12, 13, 55);
    final deletedAt = createdAt.add(const Duration(minutes: 4));

    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'server-accepted-create-local-failed',
        deduplicationKey: 'server-accepted-create-local-failed',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-001',
        operationType: SyncQueueOperationType.create,
        payload: const <String, dynamic>{'name': 'test'},
        createdAt: createdAt,
        priority: 10,
      ),
    );
    final claimedCreate = await database.claimSyncOperation(
      'server-accepted-create-local-failed',
      userId: 'user-001',
      now: createdAt,
    );
    await database.markSyncOperationFailed(
      claimedCreate!.id,
      userId: 'user-001',
      failedAt: createdAt,
      error: StateError('post-create location failed'),
      exhaust: true,
    );

    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'completed-delete-001',
        deduplicationKey: 'completed-delete-001',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-001',
        operationType: SyncQueueOperationType.deleteEntity,
        payload: const <String, dynamic>{},
        createdAt: deletedAt,
        priority: 20,
      ),
    );
    final claimedDelete = await database.claimSyncOperation(
      'completed-delete-001',
      userId: 'user-001',
      now: deletedAt,
    );
    await database.markSyncOperationCompleted(
      claimedDelete!.id,
      userId: 'user-001',
      completedAt: deletedAt,
      remoteResult: const <String, dynamic>{
        'operation_id': 'completed-delete-001',
        'operation_type': 'delete',
        'entity_id': 'business-001',
        'remote_status': 'deleted',
      },
    );

    final operations = await database.readSyncOperations(userId: 'user-001');
    expect(operations, hasLength(1));
    expect(operations.single.id, 'completed-delete-001');

    final summary = await database.readSyncQueueSummary(userId: 'user-001');
    expect(summary.failed, 0);
    expect(summary.exhausted, 0);
  });

  test('pending delete does not purge a failed create prematurely', () async {
    await database.initializeWithSeedData();
    final now = DateTime.utc(2026, 8, 12, 14);

    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'failed-create-before-pending-delete',
        deduplicationKey: 'failed-create-before-pending-delete',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-002',
        operationType: SyncQueueOperationType.create,
        payload: const <String, dynamic>{'name': 'test'},
        createdAt: now,
        priority: 10,
      ),
    );
    final claimedCreate = await database.claimSyncOperation(
      'failed-create-before-pending-delete',
      userId: 'user-001',
      now: now,
    );
    await database.markSyncOperationFailed(
      claimedCreate!.id,
      userId: 'user-001',
      failedAt: now,
      error: StateError('post-create failure'),
      exhaust: true,
    );

    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'pending-delete-002',
        deduplicationKey: 'pending-delete-002',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-002',
        operationType: SyncQueueOperationType.deleteEntity,
        payload: const <String, dynamic>{},
        createdAt: now.add(const Duration(minutes: 1)),
        priority: 20,
      ),
    );

    final operations = await database.readSyncOperations(userId: 'user-001');
    expect(
        operations.map((item) => item.id).toSet(),
        containsAll(<String>{
          'failed-create-before-pending-delete',
          'pending-delete-002',
        }));
  });
}
