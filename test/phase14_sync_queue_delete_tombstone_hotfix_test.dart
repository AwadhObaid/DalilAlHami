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

  test('delete supersedes an older queued update for the same business',
      () async {
    await database.initializeWithSeedData();
    final updateAt = DateTime.utc(2026, 8, 11, 8);
    final deleteAt = updateAt.add(const Duration(minutes: 5));

    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-update-001',
        deduplicationKey: 'operation-update-001',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-001',
        operationType: SyncQueueOperationType.update,
        payload: const {'name': 'طھط¹ط¯ظٹظ„ ظ‚ط¯ظٹظ…'},
        createdAt: updateAt,
        priority: 10,
      ),
    );
    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-delete-001',
        deduplicationKey: 'operation-delete-001',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-001',
        operationType: SyncQueueOperationType.deleteEntity,
        payload: const {},
        createdAt: deleteAt,
        priority: 20,
      ),
    );

    final items = await database.readSyncOperations(userId: 'user-001');
    expect(items, hasLength(1));
    expect(items.single.id, 'operation-delete-001');
  });

  test('legacy stale update is removed after a newer completed delete',
      () async {
    await database.initializeWithSeedData();
    final updateAt = DateTime.utc(2026, 8, 11, 8);
    final deleteAt = updateAt.add(const Duration(minutes: 5));

    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-delete-legacy',
        deduplicationKey: 'operation-delete-legacy',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-legacy',
        operationType: SyncQueueOperationType.deleteEntity,
        payload: const {},
        createdAt: deleteAt,
        priority: 20,
      ),
    );
    final claimed = await database.claimSyncOperation(
      'operation-delete-legacy',
      userId: 'user-001',
      now: deleteAt,
    );
    await database.markSyncOperationCompleted(
      claimed!.id,
      userId: 'user-001',
      completedAt: deleteAt,
      remoteResult: const {
        'operation_id': 'operation-delete-legacy',
        'operation_type': 'delete',
        'entity_id': 'business-legacy',
        'remote_status': 'deleted',
      },
    );

    // Simulates a stale queue row left by an older installed build.
    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-update-legacy',
        deduplicationKey: 'operation-update-legacy',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-legacy',
        operationType: SyncQueueOperationType.update,
        payload: const {'name': 'ط¹ظ…ظ„ظٹط© ظ‚ط¯ظٹظ…ط©'},
        createdAt: updateAt,
        priority: 10,
      ),
    );

    final items = await database.readSyncOperations(userId: 'user-001');
    expect(items, hasLength(1));
    expect(items.single.id, 'operation-delete-legacy');
    final summary = await database.readSyncQueueSummary(userId: 'user-001');
    expect(summary.failed, 0);
    expect(summary.exhausted, 0);
  });

  test('delete does not remove an operation for another business', () async {
    await database.initializeWithSeedData();
    final now = DateTime.utc(2026, 8, 11, 9);

    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-update-other',
        deduplicationKey: 'operation-update-other',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-002',
        operationType: SyncQueueOperationType.update,
        payload: const {'name': 'ظ†ط´ط§ط· ط¢ط®ط±'},
        createdAt: now,
        priority: 10,
      ),
    );
    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-delete-first',
        deduplicationKey: 'operation-delete-first',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-001',
        operationType: SyncQueueOperationType.deleteEntity,
        payload: const {},
        createdAt: now.add(const Duration(minutes: 1)),
        priority: 20,
      ),
    );

    final items = await database.readSyncOperations(userId: 'user-001');
    expect(items, hasLength(2));
    expect(items.any((item) => item.id == 'operation-update-other'), isTrue);
    expect(items.any((item) => item.id == 'operation-delete-first'), isTrue);
  });
}
