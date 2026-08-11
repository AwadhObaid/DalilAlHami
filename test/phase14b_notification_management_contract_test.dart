import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'Phase 14B user dismissal is per-user and never hard-deletes notifications',
      () {
    final migration = File(
      'supabase/migrations/20260811173000_phase14b_notification_management.sql',
    ).readAsStringSync();

    for (final token in <String>[
      'app_notification_dismissals',
      'dismiss_my_notification',
      'dismiss_my_notifications',
      'dismiss_all_my_notifications',
      'not exists (',
      'd.user_id = v_user_id',
      'admin_hidden_at',
    ]) {
      expect(migration, contains(token), reason: token);
    }

    expect(
      migration,
      isNot(contains('delete from public.app_notifications')),
      reason: 'User dismissal must never delete the shared notification row.',
    );
  });

  test('Phase 14B admin cleanup hides history without deleting user inbox rows',
      () {
    final edgeFunction = File(
      'supabase/functions/admin-notifications/index.ts',
    ).readAsStringSync();

    for (final token in <String>[
      "action === 'hide_history'",
      "action === 'clear_history'",
      ".update({ admin_hidden_at:",
      ".is('admin_hidden_at', null)",
      "action === 'history'",
    ]) {
      expect(edgeFunction, contains(token), reason: token);
    }

    expect(
      edgeFunction,
      isNot(contains(".from('app_notifications').delete(")),
      reason: 'Admin history cleanup must not hard-delete notification rows.',
    );
  });

  test('Flutter repositories expose Phase 14B management operations', () {
    final userRepository = File(
      'lib/data/repositories/notification_repository.dart',
    ).readAsStringSync();
    for (final token in <String>[
      "'dismiss_my_notification'",
      "'dismiss_my_notifications'",
      "'dismiss_all_my_notifications'",
      'Future<bool> dismiss(',
      'Future<int> dismissMany(',
      'Future<int> dismissAll()',
    ]) {
      expect(userRepository, contains(token), reason: token);
    }

    final adminRepository = File(
      'lib/data/repositories/admin_notification_repository.dart',
    ).readAsStringSync();
    for (final token in <String>[
      "'hide_history'",
      "'clear_history'",
      'Future<int> hideHistory(',
      'Future<int> clearHistory()',
    ]) {
      expect(adminRepository, contains(token), reason: token);
    }
  });

  test('notification UIs expose single, multi-select, and clear-all controls',
      () {
    final center = File(
      'lib/features/notifications/notification_center_page.dart',
    ).readAsStringSync();
    for (final token in <String>[
      'notification-clear-all',
      'notification-delete-selected',
      'notification-select-all',
      'notification-delete-',
      'onLongPress',
    ]) {
      expect(center, contains(token), reason: token);
    }

    final admin = File(
      'lib/features/admin/admin_notification_management_page.dart',
    ).readAsStringSync();
    for (final token in <String>[
      'admin-notification-history-clear',
      'admin-notification-history-hide-selected',
      'admin-notification-history-select-all',
      'admin-notification-history-delete-',
      'onLongPress',
      'لن يُحذف الإشعار من المستخدمين',
    ]) {
      expect(admin, contains(token), reason: token);
    }
  });
}
