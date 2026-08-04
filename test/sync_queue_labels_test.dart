import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_item.dart';

void main() {
  test('تتوفر تسميات عربية واضحة لعمليات وحالات الطابور', () {
    expect(SyncQueueOperationType.create.label, 'إضافة نشاط');
    expect(SyncQueueOperationType.update.label, 'تعديل نشاط');
    expect(SyncQueueOperationType.deleteEntity.label, 'حذف نشاط');
    expect(SyncQueueStatus.pending.label, 'بانتظار المزامنة');
    expect(SyncQueueStatus.completed.label, 'تمت المزامنة');
  });
}
