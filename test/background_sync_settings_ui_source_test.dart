import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account page exposes background sync settings', () {
    final account = File(
      'lib/features/profile/account_hub_page.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/profile/background_sync_settings_page.dart',
    ).readAsStringSync();

    expect(account, contains('المزامنة في الخلفية'));
    expect(account, contains('BackgroundSyncSettingsPage'));
    expect(settings, contains('background-sync-enabled-switch'));
    expect(settings, contains('إشعارات الفشل والتعارض'));
    expect(settings, contains('اختبار الجدولة الآن'));
  });
}
