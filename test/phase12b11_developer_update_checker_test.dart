import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String settingsSource;
  late String updateServiceSource;
  late String splashSource;
  late String appSource;
  late String pubspecSource;

  setUpAll(() {
    settingsSource =
        File('lib/features/settings/app_settings_page.dart').readAsStringSync();
    updateServiceSource =
        File('lib/core/services/app_update_service.dart').readAsStringSync();
    splashSource =
        File('lib/features/splash/splash_screen.dart').readAsStringSync();
    appSource = File('lib/app/hami_guide_app.dart').readAsStringSync();
    pubspecSource = File('pubspec.yaml').readAsStringSync();
  });

  test('settings contracts use stable keys instead of localized text', () {
    expect(settingsSource, contains('settings-app-idea-credit'));
    expect(settingsSource, contains('settings-app-development-credit'));
    expect(settingsSource, contains('settings-check-updates'));
    expect(settingsSource, contains('settings-download-update'));
    expect(settingsSource, contains('AppUpdateService'));
  });

  test('GitHub update service targets public releases repository', () {
    // Verify the semantic Uri.https construction instead of a rendered URL string.
    expect(updateServiceSource, contains("repositoryOwner = 'AwadhObaid'"));
    expect(
      updateServiceSource,
      contains("repositoryName = 'DalilAlHami-Releases'"),
    );
    expect(
      updateServiceSource,
      contains("'api.github.com'"),
    );
    expect(
      updateServiceSource,
      contains("'/repos/\$repositoryOwner/\$repositoryName/releases'"),
    );
    expect(
      updateServiceSource,
      contains("const <String, String>{'per_page': '20'}"),
    );
    expect(updateServiceSource, contains("endsWith('.apk')"));

    final versionMatch = RegExp(
      r'^version:\s+([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?\+[0-9]+)\s*$',
      multiLine: true,
    ).firstMatch(pubspecSource);

    expect(
      versionMatch,
      isNotNull,
      reason: 'pubspec.yaml must contain a publishable semantic version.',
    );
  });

  test('startup update check remains injectable and bounded', () {
    expect(splashSource, contains('updateCheckOverride'));
    expect(splashSource, contains('StartupUpdateCheck'));
    expect(splashSource, contains('AppUpdateService'));
    expect(splashSource, contains('.timeout('));
  });

  test('app wires the startup update override into SplashScreen', () {
    expect(appSource, contains('startupUpdateCheck'));
    expect(appSource, contains('SplashScreen('));
    expect(appSource, contains('updateCheckOverride: startupUpdateCheck'));
  });

  test('required updater dependencies are declared', () {
    expect(pubspecSource, contains('http: ^1.4.0'));
    expect(pubspecSource, contains('url_launcher: ^6.2.1'));
    expect(pubspecSource, contains('package_info_plus: ^10.2.1'));
  });
}
