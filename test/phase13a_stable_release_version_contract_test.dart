import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/app_update_service.dart';

void main() {
  test('stable 1.0.7 supersedes final beta 1.0.7-beta', () {
    final beta = AppSemanticVersion.tryParse('1.0.7-beta+8');
    final stable = AppSemanticVersion.tryParse('v1.0.7');

    expect(beta, isNotNull);
    expect(stable, isNotNull);

    expect(beta!.normalized, '1.0.7-beta');
    expect(beta.isPrerelease, isTrue);

    expect(stable!.normalized, '1.0.7');
    expect(stable.isPrerelease, isFalse);

    expect(stable.compareTo(beta), greaterThan(0));
    expect(beta.compareTo(stable), lessThan(0));
  });

  test('build metadata does not change semantic release ordering', () {
    final packageVersion = AppSemanticVersion.tryParse('1.0.7+9');
    final githubTag = AppSemanticVersion.tryParse('v1.0.7');

    expect(packageVersion, isNotNull);
    expect(githubTag, isNotNull);
    expect(packageVersion!.compareTo(githubTag!), 0);
    expect(packageVersion.normalized, '1.0.7');
  });

  test(
      'current pubspec remains stable and is not older than first stable 1.0.7',
      () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    final versionLine = RegExp(
      r'^version:\s+([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(
      versionLine,
      isNotNull,
      reason:
          'pubspec must contain a stable semantic version, not a prerelease.',
    );

    final current = AppSemanticVersion.tryParse(versionLine!.group(1)!);
    final firstStable = AppSemanticVersion.tryParse('1.0.7');

    expect(current, isNotNull);
    expect(firstStable, isNotNull);
    expect(current!.isPrerelease, isFalse);
    expect(current.compareTo(firstStable!), greaterThanOrEqualTo(0));

    expect(
      RegExp(
        r'^version:\s+1\.0\.7-beta\+8\s*$',
        multiLine: true,
      ).hasMatch(pubspec),
      isFalse,
    );
  });

  test('stable installations continue to ignore GitHub prereleases', () {
    final updateService =
        File('lib/core/services/app_update_service.dart').readAsStringSync();

    expect(
      updateService,
      contains('final allowPrereleases = current.isPrerelease;'),
    );
    expect(
      updateService,
      contains('if (release.isPrerelease && !allowPrereleases)'),
    );
  });
}
