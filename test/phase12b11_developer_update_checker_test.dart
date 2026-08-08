import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/app_update_service.dart';

void main() {
  test('semantic version ordering protects stable users from beta ordering',
      () {
    final oldBeta = AppSemanticVersion.tryParse('v1.0.3-beta')!;
    final stable = AppSemanticVersion.tryParse('1.0.3')!;
    final newerBeta = AppSemanticVersion.tryParse('v1.0.4-beta.2')!;

    expect(stable.compareTo(oldBeta), greaterThan(0));
    expect(newerBeta.compareTo(stable), greaterThan(0));
    expect(
      AppSemanticVersion.tryParse('1.0.4-beta.10')!
          .compareTo(AppSemanticVersion.tryParse('1.0.4-beta.2')!),
      greaterThan(0),
    );
  });

  test('developer credits and manual update controls are wired in settings',
      () {
    final settings = File(
      'lib/features/settings/app_settings_page.dart',
    ).readAsStringSync();

    for (final token in <String>[
      'settings-app-idea-credit',
      'الغريم سالم',
      'settings-app-development-credit',
      'المهندس عوض بن قفلة',
      'settings-check-updates',
      'settings-download-update',
      'AppUpdateService',
      '_loadCurrentVersionLabel',
    ]) {
      expect(settings, contains(token), reason: token);
    }

    expect(settings, isNot(contains('_initializeUpdateSection')));
  });

  test('startup update check is wired to SplashScreen', () {
    final splash = File(
      'lib/features/splash/splash_screen.dart',
    ).readAsStringSync();

    for (final token in <String>[
      'AppUpdateService',
      '_checkForStartupUpdate',
      'startup-update-dialog',
      'startup-update-download',
      'startup-update-later',
      'release.preferredDownloadUri',
      'Duration(seconds: 5)',
      'Update checks must never prevent the application from opening.',
    ]) {
      expect(splash, contains(token), reason: token);
    }
  });

  test('startup update check is injectable for deterministic widget tests', () {
    final splash = File(
      'lib/features/splash/splash_screen.dart',
    ).readAsStringSync();
    final app = File(
      'lib/app/hami_guide_app.dart',
    ).readAsStringSync();
    final widgetTest = File(
      'test/widget_test.dart',
    ).readAsStringSync();

    expect(splash, contains('typedef StartupUpdateCheck'));
    expect(splash, contains('updateCheckOverride'));
    expect(app, contains('startupUpdateCheck'));
    expect(app, contains('updateCheckOverride: startupUpdateCheck'));
    expect(widgetTest, contains('startupUpdateCheck: () async => null'));
  });

  test('GitHub update service targets public releases repository', () {
    final updater = File(
      'lib/core/services/app_update_service.dart',
    ).readAsStringSync();
    for (final token in <String>[
      'AwadhObaid',
      'DalilAlHami-Releases',
      'api.github.com',
      "endsWith('.apk')",
      'release.isPrerelease && !allowPrereleases',
    ]) {
      expect(updater, contains(token), reason: token);
    }

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: 1.0.3-beta+4'));
    expect(pubspec, contains('http:'));
    expect(pubspec, contains('package_info_plus:'));
  });
}
