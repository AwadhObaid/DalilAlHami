import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account profile async refresh is fenced to the requesting user', () {
    final source =
        File('lib/core/services/auth_session_store.dart').readAsStringSync();

    expect(source, contains('String? _refreshingAccountProfileUserId;'));
    expect(source, contains('final requestedUserId = currentUser.id;'));
    expect(
      source,
      contains('_refreshingAccountProfileUserId == requestedUserId'),
    );
    expect(source, contains('if (user?.id != requestedUserId)'));
    expect(
      source,
      contains(
        'if (profile.id != requestedUserId || user?.id != requestedUserId)',
      ),
    );
    expect(
      source,
      contains('_refreshingAccountProfileUserId = null;'),
    );
  });

  test('notification unread count is fenced to the active account', () {
    final source = File('lib/core/services/app_notification_store.dart')
        .readAsStringSync();

    expect(source, contains('String? _activeUserId;'));
    expect(source, contains('String? _refreshingUserId;'));
    expect(source, contains('final nextUserId = state.session?.user.id;'));
    expect(source, contains('_setUnreadCount(0);'));
    expect(
      source,
      contains(
        'final requestedUserId = SupabaseService.client.auth.currentUser?.id;',
      ),
    );
    expect(
      source,
      contains('_refreshingUserId == requestedUserId'),
    );
    expect(
      source,
      contains(
        'SupabaseService.client.auth.currentUser?.id != requestedUserId',
      ),
    );
  });

  test('Phase 15B.2 does not weaken sign-out or push-token cleanup', () {
    final auth =
        File('lib/core/services/auth_session_store.dart').readAsStringSync();

    expect(
      auth,
      contains(
        'await FirebasePushNotificationService.instance.unregisterCurrentToken();',
      ),
    );
    expect(auth, contains('await SupabaseService.client.auth.signOut();'));
    expect(auth, contains('_session = null;'));
    expect(auth, contains('_accountProfile = null;'));
  });
}
