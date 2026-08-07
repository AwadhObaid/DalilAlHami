import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/push_notification_intent.dart';
import 'package:hami_guide/models/app_notification.dart';

void main() {
  test('notification row maps read state and in-app destination', () {
    final item = AppNotification.fromMap(<String, dynamic>{
      'id': 'notification-1',
      'title': 'تنبيه جديد',
      'body': 'تم تحديث بيانات النشاط.',
      'target_type': 'user',
      'navigation_type': 'business',
      'business_id': 'business-42',
      'created_at': '2026-08-07T15:00:00Z',
      'is_read': false,
      'data': <String, dynamic>{'source': 'admin'},
    });

    expect(item.id, 'notification-1');
    expect(item.isRead, isFalse);
    expect(item.intent?.target, PushNotificationTarget.business);
    expect(item.intent?.businessId, 'business-42');
    expect(item.copyWith(isRead: true).isRead, isTrue);
  });

  test('notification center destination is supported', () {
    final item = AppNotification.fromMap(<String, dynamic>{
      'id': 'notification-2',
      'title': 'رسالة عامة',
      'body': 'مرحبًا بكم في دليل الحامي.',
      'target_type': 'public',
      'navigation_type': 'notifications',
      'created_at': '2026-08-07T15:00:00Z',
      'is_read': true,
    });

    expect(item.intent?.target, PushNotificationTarget.notifications);
  });
}
