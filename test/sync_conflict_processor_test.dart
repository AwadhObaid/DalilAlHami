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

  test('يوقف العملية عند التعارض ويحفظ النسخة المحلية والخادم', () async {
    await database.initializeWithSeedData();
    final now = DateTime.utc(2026, 8, 4, 18, 30);

    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-conflict-001',
        deduplicationKey: 'operation-conflict-001',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-001',
        operationType: SyncQueueOperationType.update,
        payload: const <String, dynamic>{
          'name': 'الاسم المحلي',
          '_base_sync_version': 12,
        },
        createdAt: now,
      ),
    );

    final processor = SyncQueueProcessor(
      database: database,
      gateway: const _ConflictGateway(),
      userId: 'user-001',
      clock: () => now,
    );

    final report = await processor.processPending();
    final conflicts = await database.readSyncConflicts(
      userId: 'user-001',
      pendingOnly: true,
    );
    final operations = await database.readSyncOperations(
      userId: 'user-001',
    );

    expect(report.conflicts, 1);
    expect(report.completed, 0);
    expect(conflicts, hasLength(1));
    expect(conflicts.single.localPayload['name'], 'الاسم المحلي');
    expect(conflicts.single.serverSnapshot['name'], 'اسم الخادم');
    expect(conflicts.single.serverSyncVersion, 15);
    expect(operations.single.status, SyncQueueStatus.failed);
    expect(operations.single.isExhausted, isTrue);
  });
}

class _ConflictGateway implements SyncQueueRemoteGateway {
  const _ConflictGateway();

  @override
  Future<SyncQueueRemoteResult> execute(SyncQueueItem item) async {
    return SyncQueueRemoteResult(
      operationId: item.id,
      operationType: item.operationType.databaseValue,
      entityId: item.entityId,
      remoteStatus: 'conflict',
      conflictId: 'conflict-001',
      expectedSyncVersion: 12,
      serverSyncVersion: 15,
      serverSnapshot: const <String, dynamic>{
        'id': 'business-001',
        'owner_id': 'user-001',
        'category_id': 'category-001',
        'category_name': 'مطاعم',
        'name': 'اسم الخادم',
        'description': '',
        'phone': '777000111',
        'whatsapp': '777000111',
        'address': 'الحامي',
        'status': 'approved',
        'is_active': true,
        'sync_version': 15,
      },
      raw: const <String, dynamic>{
        'operation_id': 'operation-conflict-001',
        'operation_type': 'update',
        'entity_id': 'business-001',
        'remote_status': 'conflict',
        'conflict_id': 'conflict-001',
        'expected_sync_version': 12,
        'server_sync_version': 15,
        'server_snapshot': <String, dynamic>{
          'name': 'اسم الخادم',
        },
      },
    );
  }
}
