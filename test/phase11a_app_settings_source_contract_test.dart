import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 11A app settings and preferences are wired', () {
    final preferences = File(
      'lib/core/services/app_preferences_store.dart',
    ).readAsStringSync();
    for (final token in <String>[
      'AppPreferencesStore',
      'AppTextScalePreset',
      'phase11_public_notifications_enabled_v1',
      'textScaleFactor',
      'resetUserFacingPreferences',
    ]) {
      expect(preferences, contains(token), reason: token);
    }

    final settings = File(
      'lib/features/settings/app_settings_page.dart',
    ).readAsStringSync();
    for (final token in <String>[
      'app-settings-list',
      'settings-text-scale-large',
      'settings-public-notifications-switch',
      'settings-notification-permission-status',
      'settings-language-en',
      'settings-reset-defaults',
    ]) {
      expect(settings, contains(token), reason: token);
    }

    final app = File('lib/app/hami_guide_app.dart').readAsStringSync();
    for (final token in <String>[
      'GlobalMaterialLocalizations.delegate',
      "Locale('ar')",
      "Locale('en')",
      'snapshot.textScaleFactor',
      'TextScaler.linear',
    ]) {
      expect(app, contains(token), reason: token);
    }

    final push = File(
      'lib/core/services/firebase_push_notification_service.dart',
    ).readAsStringSync();
    expect(push, contains('applyPublicTopicPreference'));
    expect(push, contains('unsubscribeFromTopic(publicTopicName)'));
    expect(push, contains('subscribeToTopic(publicTopicName)'));

    final account = File(
      'lib/features/profile/account_hub_page.dart',
    ).readAsStringSync();
    expect(account, contains('AppSettingsPage'));
    expect(account, contains("title: 'إعدادات التطبيق'"));

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('flutter_localizations:'));
    expect(pubspec, contains('sdk: flutter'));
  });
}
