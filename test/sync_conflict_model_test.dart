import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/sync_queue/sync_conflict.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_item.dart';

void main() {
  test('يحفظ تعارض المزامنة ويستعيد نسختيه', () {
    final conflict = SyncConflict(
      id: 'conflict-001',
      operationId: 'operation-001',
      userId: 'user-001',
      entityType: SyncQueueEntityType.business,
      operationType: SyncQueueOperationType.update,
      entityId: 'business-001',
      localPayload: const <String, dynamic>{
        'name': 'الاسم المحلي',
      },
      serverSnapshot: const <String, dynamic>{
        'name': 'اسم الخادم',
      },
      expectedSyncVersion: 12,
      serverSyncVersion: 15,
      status: SyncConflictStatus.pending,
      createdAt: DateTime.utc(2026, 8, 4, 18),
      updatedAt: DateTime.utc(2026, 8, 4, 18),
    );

    final restored = SyncConflict.fromDatabaseRow(
      conflict.toDatabaseRow(),
    );

    expect(restored.entityName, 'اسم الخادم');
    expect(restored.localPayload['name'], 'الاسم المحلي');
    expect(restored.serverSnapshot['name'], 'اسم الخادم');
    expect(restored.expectedSyncVersion, 12);
    expect(restored.serverSyncVersion, 15);
    expect(restored.isPending, isTrue);
  });
}
