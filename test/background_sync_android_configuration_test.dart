import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android background sync configuration is present', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final gradle = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final service = File(
      'lib/core/services/background_sync_service.dart',
    ).readAsStringSync();

    expect(pubspec, contains('workmanager: ^0.9.0+3'));
    expect(pubspec, contains('flutter_local_notifications: ^19.5.0'));
    expect(gradle, contains('isCoreLibraryDesugaringEnabled = true'));
    expect(gradle, contains('desugar_jdk_libs:2.1.4'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(service, contains("@pragma('vm:entry-point')"));
    expect(service, contains('ExistingPeriodicWorkPolicy.update'));
    expect(service, contains('NetworkType.connected'));
    expect(service, contains('Duration(minutes: 15)'));
  });
}
