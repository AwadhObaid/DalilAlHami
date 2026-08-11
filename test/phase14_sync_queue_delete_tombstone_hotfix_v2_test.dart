import 'dart:io';

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

  test(
    'completed delete removes a stale update created after the delete',
    () async {
      await database.initializeWithSeedData();

      final deleteAt = DateTime.utc(2026, 8, 11, 8);
      final staleUpdateAt = deleteAt.add(const Duration(hours: 8));

      await database.enqueueSyncOperation(
        SyncQueueEnqueueRequest(
          userId: 'user-001',
          operationId: 'delete-tombstone-001',
          deduplicationKey: 'delete-tombstone-001',
          entityType: SyncQueueEntityType.business,
          entityId: 'business-deleted-001',
          operationType: SyncQueueOperationType.deleteEntity,
          payload: const {},
          createdAt: deleteAt,
          priority: 20,
        ),
      );

      final claimedDelete = await database.claimSyncOperation(
        'delete-tombstone-001',
        userId: 'user-001',
        now: deleteAt,
      );

      await database.markSyncOperationCompleted(
        claimedDelete!.id,
        userId: 'user-001',
        completedAt: deleteAt,
        remoteResult: const <String, dynamic>{
          'operation_id': 'delete-tombstone-001',
          'operation_type': 'delete',
          'entity_id': 'business-deleted-001',
          'remote_status': 'deleted',
        },
      );

      // Simulates a stale account screen creating a mutation hours after deletion.
      await database.enqueueSyncOperation(
        SyncQueueEnqueueRequest(
          userId: 'user-001',
          operationId: 'late-stale-update-001',
          deduplicationKey: 'late-stale-update-001',
          entityType: SyncQueueEntityType.business,
          entityId: 'business-deleted-001',
          operationType: SyncQueueOperationType.update,
          payload: const <String, dynamic>{'name': 'stale edit'},
          createdAt: staleUpdateAt,
          priority: 10,
        ),
      );

      final operations = await database.readSyncOperations(userId: 'user-001');

      expect(operations, hasLength(1));
      expect(operations.single.id, 'delete-tombstone-001');

      final summary = await database.readSyncQueueSummary(userId: 'user-001');
      expect(summary.failed, 0);
      expect(summary.exhausted, 0);
      expect(summary.pending, 0);
    },
  );

  test(
    'retry cleans an exhausted stale update behind a completed delete',
    () async {
      await database.initializeWithSeedData();

      final deleteAt = DateTime.utc(2026, 8, 11, 9);
      final updateAt = deleteAt.add(const Duration(hours: 1));

      await database.enqueueSyncOperation(
        SyncQueueEnqueueRequest(
          userId: 'user-001',
          operationId: 'delete-tombstone-retry',
          deduplicationKey: 'delete-tombstone-retry',
          entityType: SyncQueueEntityType.business,
          entityId: 'business-deleted-retry',
          operationType: SyncQueueOperationType.deleteEntity,
          payload: const {},
          createdAt: deleteAt,
          priority: 20,
        ),
      );
      final claimedDelete = await database.claimSyncOperation(
        'delete-tombstone-retry',
        userId: 'user-001',
        now: deleteAt,
      );
      await database.markSyncOperationCompleted(
        claimedDelete!.id,
        userId: 'user-001',
        completedAt: deleteAt,
        remoteResult: const <String, dynamic>{
          'operation_id': 'delete-tombstone-retry',
          'operation_type': 'delete',
          'entity_id': 'business-deleted-retry',
          'remote_status': 'deleted',
        },
      );

      await database.enqueueSyncOperation(
        SyncQueueEnqueueRequest(
          userId: 'user-001',
          operationId: 'failed-late-update',
          deduplicationKey: 'failed-late-update',
          entityType: SyncQueueEntityType.business,
          entityId: 'business-deleted-retry',
          operationType: SyncQueueOperationType.update,
          payload: const <String, dynamic>{'name': 'orphan'},
          createdAt: updateAt,
          priority: 10,
        ),
      );

      final claimedUpdate = await database.claimSyncOperation(
        'failed-late-update',
        userId: 'user-001',
        now: updateAt,
      );
      await database.markSyncOperationFailed(
        claimedUpdate!.id,
        userId: 'user-001',
        failedAt: updateAt,
        error: StateError('42501 missing business'),
        exhaust: true,
      );

      final retried = await database.retryFailedSyncOperations(
        userId: 'user-001',
        operationId: 'failed-late-update',
        now: updateAt.add(const Duration(minutes: 1)),
      );

      expect(retried, 0);

      final operations = await database.readSyncOperations(userId: 'user-001');
      expect(operations, hasLength(1));
      expect(operations.single.id, 'delete-tombstone-retry');

      final summary = await database.readSyncQueueSummary(userId: 'user-001');
      expect(summary.failed, 0);
      expect(summary.exhausted, 0);
    },
  );

  test('a different new business is not affected by an old tombstone',
      () async {
    await database.initializeWithSeedData();

    final now = DateTime.utc(2026, 8, 11, 10);

    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'old-delete',
        deduplicationKey: 'old-delete',
        entityType: SyncQueueEntityType.business,
        entityId: 'old-business-id',
        operationType: SyncQueueOperationType.deleteEntity,
        payload: const {},
        createdAt: now,
        priority: 20,
      ),
    );

    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'new-business-update',
        deduplicationKey: 'new-business-update',
        entityType: SyncQueueEntityType.business,
        entityId: 'new-business-id',
        operationType: SyncQueueOperationType.update,
        payload: const <String, dynamic>{'name': 'new business'},
        createdAt: now.add(const Duration(minutes: 1)),
        priority: 10,
      ),
    );

    final operations = await database.readSyncOperations(userId: 'user-001');

    expect(
      operations.map((item) => item.id),
      containsAll(<String>['old-delete', 'new-business-update']),
    );
  });

  test('Manage Business isolates account state after sign-out', () {
    final source =
        File('lib/features/profile/profile_page.dart').readAsStringSync();

    expect(
      source,
      contains(
          'final AuthSessionStore _authStore = AuthSessionStore.instance;'),
    );
    expect(
      source,
      contains('_authStore.addListener(_handleAuthChanged);'),
    );
    expect(
      source,
      contains('_authStore.removeListener(_handleAuthChanged);'),
    );
    expect(source, contains('void _handleAuthChanged()'));
    expect(
      source,
      contains("_loadError = 'انتهت جلسة تسجيل الدخول.';"),
    );
    expect(
      source,
      contains(
        'if (_authStore.isAuthenticated &&\n'
        '              (_directoryStore.pendingSyncOperationCount > 0 ||',
      ),
    );
  });
}
