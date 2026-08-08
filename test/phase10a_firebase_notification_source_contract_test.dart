import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 10A Firebase notification foundation is wired', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('firebase_core: ^4.12.1'));
    expect(pubspec, contains('firebase_messaging: ^16.4.3'));

    final mainSource = File('lib/main.dart').readAsStringSync();
    expect(mainSource, contains('Firebase.initializeApp'));
    expect(mainSource, contains('FirebaseMessaging.onBackgroundMessage'));
    expect(mainSource, contains('FirebasePushNotificationService'));

    final service = File(
      'lib/core/services/firebase_push_notification_service.dart',
    ).readAsStringSync();
    for (final token in <String>[
      'firebaseMessagingBackgroundHandler',
      'FirebaseMessaging.onMessage',
      'FirebaseMessaging.onMessageOpenedApp',
      'getInitialMessage()',
      'onTokenRefresh',
      'requestPermission(',
      'syncCurrentToken()',
      'unregisterCurrentToken()',
      "subscribeToTopic(publicTopicName)",
    ]) {
      expect(service, contains(token), reason: token);
    }

    final repository = File(
      'lib/data/repositories/push_device_repository.dart',
    ).readAsStringSync();
    expect(repository, contains("'register_push_device'"));
    expect(repository, contains("'unregister_push_device'"));

    final authStore = File(
      'lib/core/services/auth_session_store.dart',
    ).readAsStringSync();
    expect(
      authStore.indexOf('unregisterCurrentToken()'),
      lessThan(authStore.indexOf('auth.signOut()')),
    );

    final migration = File(
      'supabase/migrations/20260807133000_firebase_push_notification_foundation.sql',
    ).readAsStringSync();
    for (final token in <String>[
      'push_notification_devices',
      'register_push_device',
      'unregister_push_device',
      'public.is_active_account()',
      'profiles_disable_push_devices_when_inactive',
      'grant all on public.push_notification_devices to service_role',
    ]) {
      expect(migration, contains(token), reason: token);
    }

    final settings = File('android/settings.gradle.kts').readAsStringSync();
    expect(
      settings,
      contains('id("com.google.gms.google-services") version "4.5.0"'),
    );

    final appGradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(appGradle, contains('id("com.google.gms.google-services")'));

    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_channel_id'),
    );
    expect(manifest, contains('dalil_alhami_push'));

    final options = File('lib/firebase_options.dart');
    final googleServices = File('android/app/google-services.json');
    expect(options.existsSync(), isTrue);
    expect(googleServices.existsSync(), isTrue);

    final decoded = jsonDecode(googleServices.readAsStringSync());
    final clients =
        (decoded as Map<String, dynamic>)['client'] as List<dynamic>;
    final packageNames = clients
        .map((client) => (client as Map<String, dynamic>)['client_info'])
        .whereType<Map<String, dynamic>>()
        .map((info) => info['android_client_info'])
        .whereType<Map<String, dynamic>>()
        .map((android) => android['package_name']?.toString())
        .whereType<String>()
        .toSet();
    expect(packageNames, contains('com.awadhobaid.dalilalhami'));
  });
}
