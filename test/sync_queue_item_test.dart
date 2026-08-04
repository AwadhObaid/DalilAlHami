import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_item.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_processor.dart';

void main() {
  test('يحفظ نموذج عملية الطابور ويعيد قراءته دون فقد البيانات', () {
    final createdAt = DateTime.utc(2026, 8, 4, 1);
    final item = SyncQueueItem(
      id: 'operation-001',
      deduplicationKey: 'business:create:local-001',
      userId: 'user-001',
      entityType: SyncQueueEntityType.business,
      entityId: 'business-001',
      operationType: SyncQueueOperationType.update,
      payload: const {
        'name': 'نشاط معدل دون إنترنت',
        'phone': '777000111',
      },
      status: SyncQueueStatus.failed,
      attemptCount: 2,
      maxAttempts: 5,
      priority: 10,
      createdAt: createdAt,
      updatedAt: createdAt,
      nextAttemptAt: createdAt.add(const Duration(minutes: 2)),
      lastError: 'network unavailable',
    );

    final restored = SyncQueueItem.fromDatabaseRow(
      item.toDatabaseRow(),
    );

    expect(restored.id, item.id);
    expect(restored.operationType, SyncQueueOperationType.update);
    expect(restored.payload['name'], 'نشاط معدل دون إنترنت');
    expect(restored.attemptCount, 2);
    expect(restored.lastError, 'network unavailable');
  });

  test('يطبق تدرجًا محدودًا لفترات إعادة المحاولة', () {
    expect(
      SyncQueueBackoff.delayForAttempt(1),
      const Duration(seconds: 30),
    );
    expect(
      SyncQueueBackoff.delayForAttempt(2),
      const Duration(minutes: 2),
    );
    expect(
      SyncQueueBackoff.delayForAttempt(3),
      const Duration(minutes: 10),
    );
    expect(
      SyncQueueBackoff.delayForAttempt(4),
      const Duration(minutes: 30),
    );
    expect(
      SyncQueueBackoff.delayForAttempt(5),
      const Duration(hours: 2),
    );
  });

  test('يرفض عملية تحديث دون معرف النشاط', () {
    final request = SyncQueueEnqueueRequest(
      userId: 'user-001',
      operationId: 'operation-002',
      deduplicationKey: 'operation-002',
      entityType: SyncQueueEntityType.business,
      operationType: SyncQueueOperationType.update,
      payload: const {'name': 'اختبار'},
    );

    expect(request.validate, throwsArgumentError);
  });
}
