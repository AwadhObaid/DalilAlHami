import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 10B notification center and admin send are wired securely', () {
    final migration = File(
      'supabase/migrations/20260807193000_notification_center_admin_send.sql',
    ).readAsStringSync();
    for (final token in <String>[
      'app_notifications',
      'app_notification_reads',
      'list_my_notifications',
      'my_notification_unread_count',
      'mark_my_notification_read',
      'mark_all_my_notifications_read',
      'grant all on public.app_notifications to service_role',
    ]) {
      expect(migration, contains(token), reason: token);
    }

    final edgeFunction = File(
      'supabase/functions/admin-notifications/index.ts',
    ).readAsStringSync();
    for (final token in <String>[
      'FIREBASE_SERVICE_ACCOUNT_JSON',
      'https://www.googleapis.com/auth/firebase.messaging',
      'fcm.googleapis.com/v1/projects/',
      "topic: 'dalil_alhami_public'",
      "action === 'send'",
      "action === 'history'",
      "action === 'user_options'",
    ]) {
      expect(edgeFunction, contains(token), reason: token);
    }

    final center = File(
      'lib/features/notifications/notification_center_page.dart',
    ).readAsStringSync();
    expect(center, contains('notification-mark-all-read'));
    expect(center, contains('notification-center-list'));

    final header = File(
      'lib/features/home/widgets/home_header.dart',
    ).readAsStringSync();
    expect(header, contains('unreadNotificationCount'));
    expect(header, contains('home-notification-button'));

    final adminDashboard = File(
      'lib/features/admin/admin_dashboard_page.dart',
    ).readAsStringSync();
    expect(
      adminDashboard,
      contains('admin-manage-notifications-action'),
    );

    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in dartFiles) {
      expect(
        file.readAsStringSync(),
        isNot(contains('FIREBASE_SERVICE_ACCOUNT_JSON')),
        reason: 'Firebase service-account material must stay out of Flutter.',
      );
    }
  });
}
