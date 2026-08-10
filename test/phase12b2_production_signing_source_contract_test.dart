import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production signing never falls back to the Android debug key', () {
    final gradle = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();

    expect(gradle, contains('create("production")'));
    expect(
      gradle,
      contains('signingConfig = signingConfigs.getByName("production")'),
    );
    expect(
      gradle,
      isNot(contains('signingConfig = signingConfigs.getByName("debug")')),
    );
    expect(gradle, contains('DALIL_SIGNING_MODE'));
    expect(gradle, contains('DALIL_APP_STORE_PASSWORD'));
    expect(gradle, contains('DALIL_UPLOAD_STORE_PASSWORD'));
    expect(gradle, contains('rootProject.file("key.properties")'));
  });

  test('local signing metadata stays private and password-free when present', () {
    final gitignore = File('.gitignore').readAsStringSync();

    expect(gitignore, contains('android/key.properties'));
    expect(gitignore, contains('*.jks'));
    expect(gitignore, contains('*.keystore'));

    final propertiesFile = File('android/key.properties');

    // Fresh clones and CI intentionally do not have this ignored local file.
    if (!propertiesFile.existsSync()) {
      return;
    }

    final properties = propertiesFile.readAsStringSync();

    expect(properties, contains('appStoreFile='));
    expect(properties, contains('appKeyAlias=dalilalhami_app'));
    expect(properties, contains('uploadStoreFile='));
    expect(properties, contains('uploadKeyAlias=dalilalhami_upload'));

    expect(properties.toLowerCase(), isNot(contains('password=')));
    expect(properties, isNot(contains('storePassword')));
    expect(properties, isNot(contains('keyPassword')));
  });
}