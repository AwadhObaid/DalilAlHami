import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Phase 12B1 Android production identity contract', () {
    const productionPackage = 'com.awadhobaid.dalilalhami';
    const firebaseProject = 'dalilalhami-504320';

    test('Gradle uses the permanent production package identity', () {
      final gradle = _read('android/app/build.gradle.kts');
      expect(gradle, contains('namespace = "$productionPackage"'));
      expect(gradle, contains('applicationId = "$productionPackage"'));
      expect(gradle, isNot(contains('com.example.dalilalhami')));
    });

    test('MainActivity lives under and declares the production package', () {
      final expected = File(
        'android/app/src/main/kotlin/com/awadhobaid/dalilalhami/MainActivity.kt',
      );
      final legacy = File(
        'android/app/src/main/kotlin/com/example/dalilalhami/MainActivity.kt',
      );
      expect(expected.existsSync(), isTrue);
      expect(_read(expected.path), contains('package $productionPackage'));
      expect(legacy.existsSync(), isFalse);
    });

    test('Firebase Android registration matches the production package', () {
      final decoded = jsonDecode(
        _read('android/app/google-services.json'),
      ) as Map<String, dynamic>;
      final projectInfo = decoded['project_info'] as Map<String, dynamic>;
      expect(projectInfo['project_id'], firebaseProject);

      final clients = decoded['client'] as List<dynamic>;
      final matching = clients.where((entry) {
        final client = entry as Map<String, dynamic>;
        final info = client['client_info'] as Map<String, dynamic>;
        final android = info['android_client_info'] as Map<String, dynamic>?;
        return android?['package_name'] == productionPackage;
      }).toList();
      expect(matching, isNotEmpty);

      final info = (matching.first as Map<String, dynamic>)['client_info']
          as Map<String, dynamic>;
      final mobileSdkAppId = info['mobilesdk_app_id']?.toString() ?? '';
      expect(mobileSdkAppId, isNotEmpty);
      expect(
        mobileSdkAppId,
        isNot('1:189319292547:android:7107b34a769a7a732fddb6'),
      );
    });

    test('FlutterFire options and firebase.json point to the same project', () {
      final options = _read('lib/firebase_options.dart');
      final firebaseJson = _read('firebase.json');
      expect(options, contains("projectId: '$firebaseProject'"));
      expect(firebaseJson, contains('"projectId":"$firebaseProject"'));
    });

    test('Supabase OAuth callback remains aligned to production identity', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final auth = _read('lib/core/services/google_auth_service.dart');
      expect(manifest, contains('android:scheme="$productionPackage"'));
      expect(manifest, contains('android:host="login-callback"'));
      expect(
        auth,
        contains("$productionPackage://login-callback/"),
      );
    });

    test('Firebase helper scripts default to the production package', () {
      for (final path in <String>[
        'scripts/configure_phase_10a_firebase.ps1',
        'scripts/verify_phase_10a_firebase.ps1',
      ]) {
        final source = _read(path);
        expect(source, contains(productionPackage), reason: path);
        expect(source, isNot(contains('com.example.dalilalhami')),
            reason: path);
      }
    });
  });
}
