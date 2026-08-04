import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('إعادة المحاولة اليدوية تعيد العملية المستنفدة إلى الطابور', () async {
    final database = LocalDirectoryDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final now = DateTime.utc(2026, 8, 4, 17);

    await database.initializeWithSeedData();
    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-1',
        operationId: 'failed-create-operation',
        deduplicationKey: 'failed-create-operation',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-2',
        operationType: SyncQueueOperationType.create,
        payload: const {
          'category_id': 'category-1',
          'name': 'نشاط ثانٍ',
          'phone': '777000000',
        },
        maxAttempts: 1,
        createdAt: now,
      ),
    );
    final claimed = await database.claimSyncOperation(
      'failed-create-operation',
      userId: 'user-1',
      now: now,
    );
    await database.markSyncOperationFailed(
      claimed!.id,
      userId: 'user-1',
      failedAt: now,
      error: StateError('23505 old single-owner constraint'),
      exhaust: true,
    );

    await database.retryFailedSyncOperations(
      userId: 'user-1',
      operationId: claimed.id,
      now: now.add(const Duration(minutes: 1)),
    );

    final items = await database.readSyncOperations(userId: 'user-1');
    expect(items.single.status, SyncQueueStatus.pending);
    expect(items.single.attemptCount, 0);
    expect(
      await database.readDueSyncOperations(
        userId: 'user-1',
        now: now.add(const Duration(minutes: 1)),
      ),
      hasLength(1),
    );
    await database.close();
  });
}
