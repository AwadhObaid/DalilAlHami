import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Phase 12A release-readiness source contract', () {
    test('pubspec contains a publishable semantic version', () {
      final pubspec = _read('pubspec.yaml');
      final versionPattern = RegExp(
        r'^version:\s+[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?\+[0-9]+\s*$',
        multiLine: true,
      );
      expect(versionPattern.hasMatch(pubspec), isTrue);
    });

    test('application remains bilingual and adaptive-theme capable', () {
      final app = _read('lib/app/hami_guide_app.dart');
      expect(app, contains("Locale('ar')"));
      expect(app, contains("Locale('en')"));
      expect(app, contains('GlobalMaterialLocalizations.delegate'));
      expect(app, contains('GlobalWidgetsLocalizations.delegate'));
      expect(app, contains('GlobalCupertinoLocalizations.delegate'));
      expect(app, contains('theme: AppTheme.light'));
      expect(app, contains('darkTheme: AppTheme.dark'));
      expect(app,
          contains('themeMode: snapshot.themeModePreset.materialThemeMode'));
    });

    test('Android package identifiers are internally consistent', () {
      final gradle = _read('android/app/build.gradle.kts');
      final appId = RegExp(
        r'applicationId\s*=\s*"([^"]+)"',
      ).firstMatch(gradle)!.group(1)!;

      final googleServices = jsonDecode(
        _read('android/app/google-services.json'),
      ) as Map<String, dynamic>;
      final clients = googleServices['client'] as List<dynamic>;
      final clientInfo = (clients.first as Map<String, dynamic>)['client_info']
          as Map<String, dynamic>;
      final androidClientInfo =
          clientInfo['android_client_info'] as Map<String, dynamic>;
      final firebasePackage = androidClientInfo['package_name'] as String;

      final mainActivity = _read(
        'android/app/src/main/kotlin/${appId.replaceAll('.', '/')}/MainActivity.kt',
      );

      expect(firebasePackage, appId);
      expect(mainActivity, contains('package $appId'));
    });

    test('Android app label, launcher icon, and core permissions are explicit',
        () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final strings = _read('android/app/src/main/res/values/strings.xml');
      expect(manifest, contains('android:label="@string/app_name"'));
      expect(manifest, contains('android:icon="@mipmap/launcher_icon"'));
      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
      expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
      expect(strings, contains('name="app_name"'));
    });

    test('local and release signing credentials are ignored by Git', () {
      final gitignore = _read('.gitignore').replaceAll('\\', '/');
      expect(gitignore, contains('.supabase.local.ps1'));
      expect(gitignore, contains('build_logs/'));
      expect(gitignore, contains('android/key.properties'));
      expect(gitignore, contains('*.jks'));
      expect(gitignore, contains('*.keystore'));
      expect(gitignore, contains('*.p12'));
      expect(gitignore, contains('*.pfx'));
    });

    test('Flutter runtime source does not contain privileged server keys', () {
      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      final privateKeyPattern = RegExp(
        r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\s*[A-Za-z0-9+/=\r\n]{80,}-----END',
        multiLine: true,
      );

      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('sb_secret_')), reason: file.path);
        expect(
          privateKeyPattern.hasMatch(source),
          isFalse,
          reason: file.path,
        );
      }
    });

    test('Phase 11B2 localization contracts remain present', () {
      expect(
        File('PHASE_11B2A_INLINE_AD_HEIGHT_ROUNDING_FIX_V5.txt').existsSync(),
        isTrue,
      );
      expect(File('PHASE_11B2B_ANALYSIS_FIX_V2.txt').existsSync(), isTrue);
      final localization = _read(
        'lib/core/localization/app_localized_text.dart',
      );
      expect(localization, contains('static String runtime(String value)'));
      expect(localization, contains('My businesses'));
      expect(localization, contains('Admin dashboard'));
    });
  });
}
