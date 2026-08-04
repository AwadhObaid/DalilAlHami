import 'dart:async';

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

  test('يعيد محاولة الفشل ثم يكمل العملية دون تكرارها', () async {
    await database.initializeWithSeedData();
    var now = DateTime.utc(2026, 8, 4, 5);
    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-processor-001',
        deduplicationKey: 'operation-processor-001',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-001',
        operationType: SyncQueueOperationType.update,
        payload: const {'name': 'اسم جديد'},
        createdAt: now,
      ),
    );

    final gateway = _FailOnceGateway();
    final processor = SyncQueueProcessor(
      database: database,
      gateway: gateway,
      userId: 'user-001',
      clock: () => now,
    );

    final first = await processor.processPending();
    expect(first.failed, 1);
    expect(gateway.calls, 1);

    now = now.add(const Duration(seconds: 30));
    final second = await processor.processPending();
    final summary = await database.readSyncQueueSummary(userId: 'user-001');

    expect(second.completed, 1);
    expect(gateway.calls, 2);
    expect(summary.completed, 1);
    expect(summary.actionable, 0);
  });

  test('لا يعيد محاولة خطأ الخادم الدائم', () async {
    await database.initializeWithSeedData();
    final now = DateTime.utc(2026, 8, 4, 5, 30);
    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-permanent-001',
        deduplicationKey: 'operation-permanent-001',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-001',
        operationType: SyncQueueOperationType.update,
        payload: const {'name': ''},
        createdAt: now,
      ),
    );

    final gateway = _PermanentFailureGateway();
    final processor = SyncQueueProcessor(
      database: database,
      gateway: gateway,
      userId: 'user-001',
      clock: () => now,
    );

    final report = await processor.processPending();
    final summary = await database.readSyncQueueSummary(
      userId: 'user-001',
    );
    final due = await database.readDueSyncOperations(
      userId: 'user-001',
      now: now.add(const Duration(days: 1)),
    );

    expect(report.failed, 1);
    expect(report.exhausted, 1);
    expect(summary.exhausted, 1);
    expect(due, isEmpty);
    expect(gateway.calls, 1);
  });

  test('يشارك نفس التنفيذ عند طلب المعالجة مرتين بالتزامن', () async {
    await database.initializeWithSeedData();
    final now = DateTime.utc(2026, 8, 4, 6);
    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-processor-002',
        deduplicationKey: 'operation-processor-002',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-002',
        operationType: SyncQueueOperationType.submitForReview,
        payload: const {},
        createdAt: now,
      ),
    );

    final gateway = _BlockingGateway();
    final processor = SyncQueueProcessor(
      database: database,
      gateway: gateway,
      userId: 'user-001',
      clock: () => now,
    );

    final first = processor.processPending();
    final second = processor.processPending();
    expect(identical(first, second), isTrue);

    gateway.complete();
    await Future.wait([first, second]);
    expect(gateway.calls, 1);
  });
}

class _FailOnceGateway implements SyncQueueRemoteGateway {
  var calls = 0;

  @override
  Future<SyncQueueRemoteResult> execute(SyncQueueItem item) async {
    calls++;
    if (calls == 1) {
      throw StateError('temporary network failure');
    }

    return SyncQueueRemoteResult(
      operationId: item.id,
      operationType: item.operationType.databaseValue,
      entityId: item.entityId,
      remoteStatus: 'pending',
      raw: {
        'operation_id': item.id,
        'operation_type': item.operationType.databaseValue,
        'entity_id': item.entityId,
        'remote_status': 'pending',
        'replayed': false,
      },
    );
  }
}

class _BlockingGateway implements SyncQueueRemoteGateway {
  final Completer<void> _completer = Completer<void>();
  var calls = 0;

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  @override
  Future<SyncQueueRemoteResult> execute(SyncQueueItem item) async {
    calls++;
    await _completer.future;
    return SyncQueueRemoteResult(
      operationId: item.id,
      operationType: item.operationType.databaseValue,
      entityId: item.entityId,
      remoteStatus: 'pending',
      raw: {
        'operation_id': item.id,
        'operation_type': item.operationType.databaseValue,
        'entity_id': item.entityId,
        'remote_status': 'pending',
        'replayed': false,
      },
    );
  }
}

class _PermanentFailureGateway implements SyncQueueRemoteGateway {
  var calls = 0;

  @override
  Future<SyncQueueRemoteResult> execute(SyncQueueItem item) async {
    calls++;
    throw const SyncQueueExecutionException(
      message: 'name cannot be empty',
      code: '22023',
      isRetryable: false,
    );
  }
}
