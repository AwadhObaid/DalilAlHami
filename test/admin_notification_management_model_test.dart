import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/admin_notification_management.dart';

void main() {
  test('admin notification enums expose stable server values', () {
    expect(AdminNotificationAudience.public.rpcValue, 'public');
    expect(AdminNotificationAudience.user.rpcValue, 'user');
    expect(
      AdminNotificationNavigation.notifications.rpcValue,
      'notifications',
    );
    expect(AdminNotificationNavigation.business.rpcValue, 'business');
  });

  test('history and send response are parsed safely', () {
    final history = AdminNotificationHistoryItem.fromMap(<String, dynamic>{
      'id': 'n1',
      'title': 'عنوان',
      'body': 'النص',
      'target_type': 'public',
      'navigation_type': 'home',
      'delivery_status': 'sent',
      'delivery_attempt_count': 1,
      'delivery_success_count': 1,
      'created_at': '2026-08-07T15:00:00Z',
    });
    expect(history.deliveryStatus, 'sent');
    expect(history.successCount, 1);

    final result = AdminNotificationSendResult.fromMap(<String, dynamic>{
      'notification_id': 'n1',
      'message': 'تم الإرسال',
      'delivery_status': 'sent',
      'attempt_count': 1,
      'success_count': 1,
    });
    expect(result.notificationId, 'n1');
    expect(result.message, 'تم الإرسال');
  });
}
