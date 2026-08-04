import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/data/sync_queue/sync_conflict.dart';
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

  tearDown(() async {
    await database.close();
  });

  test('اعتماد نسخة الخادم يحدث الكاش ويغلق العملية الأصلية', () async {
    await database.initializeWithSeedData();
    final now = DateTime.utc(2026, 8, 4, 19);

    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-resolution-001',
        deduplicationKey: 'operation-resolution-001',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-001',
        operationType: SyncQueueOperationType.update,
        payload: const <String, dynamic>{
          'name': 'نسخة محلية',
          '_base_sync_version': 5,
        },
        createdAt: now,
      ),
    );

    final claimed = await database.claimSyncOperation(
      'operation-resolution-001',
      userId: 'user-001',
      now: now,
    );
    await database.markSyncOperationFailed(
      claimed!.id,
      userId: 'user-001',
      failedAt: now,
      error: StateError('SYNC_CONFLICT'),
      exhaust: true,
    );

    final conflict = SyncConflict(
      id: 'conflict-resolution-001',
      operationId: claimed.id,
      userId: 'user-001',
      entityType: SyncQueueEntityType.business,
      operationType: SyncQueueOperationType.update,
      entityId: 'business-001',
      localPayload: const <String, dynamic>{
        'name': 'نسخة محلية',
      },
      serverSnapshot: const <String, dynamic>{
        'id': 'business-001',
        'owner_id': 'user-001',
        'category_id': 'category-001',
        'category_name': 'مطاعم',
        'name': 'نسخة الخادم',
        'description': 'وصف الخادم',
        'phone': '777000222',
        'whatsapp': '777000222',
        'address': 'الحامي',
        'status': 'approved',
        'is_active': true,
        'sync_version': 9,
      },
      expectedSyncVersion: 5,
      serverSyncVersion: 9,
      status: SyncConflictStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    await database.upsertSyncConflict(conflict);
    await database.applyServerConflictSnapshot(conflict);
    await database.resolveSyncConflict(
      conflict: conflict,
      resolution: SyncConflictStatus.resolvedUseServer,
      resolvedAt: now.add(const Duration(minutes: 1)),
    );

    final cached = await database.readOwnedBusinessCacheById(
      userId: 'user-001',
      businessId: 'business-001',
    );
    final conflicts = await database.readSyncConflicts(
      userId: 'user-001',
    );
    final operations = await database.readSyncOperations(
      userId: 'user-001',
    );

    expect(cached?.name, 'نسخة الخادم');
    expect(cached?.syncVersion, 9);
    expect(conflicts.single.status, SyncConflictStatus.resolvedUseServer);
    expect(operations.single.status, SyncQueueStatus.completed);
  });
}
