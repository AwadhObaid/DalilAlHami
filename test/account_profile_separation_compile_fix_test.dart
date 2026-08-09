import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _slice(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'Missing: $start');
  expect(endIndex, greaterThan(startIndex), reason: 'Missing: $end');
  return source.substring(startIndex, endIndex);
}

void main() {
  test('personal-name normalization exists only in profile update flow', () {
    final repository = File(
      'lib/data/repositories/account_repository.dart',
    ).readAsStringSync();

    final updateProfile = _slice(
      repository,
      'Future<AccountProfile> updateProfileDetails({',
      'Future<AccountProfile> clearProfileAvatar() async {',
    );

    final saveBusiness = _slice(
      repository,
      'Future<AccountSaveResult> saveAccount({',
      'Future<AccountDeleteResult> deleteOwnedBusiness(',
    );

    expect(updateProfile, contains('required String fullName'));
    expect(
      updateProfile,
      contains('final normalizedName = fullName.trim();'),
    );
    expect(updateProfile, contains('if (normalizedName.isEmpty)'));
    expect(updateProfile, contains("'full_name': normalizedName"));

    expect(saveBusiness, isNot(contains('required String fullName')));
    expect(saveBusiness, isNot(contains('fullName')));
    expect(saveBusiness, isNot(contains('normalizedName')));
    expect(
      saveBusiness,
      contains('final normalizedBusinessName = businessName.trim();'),
    );
  });

  test('obsolete coupled profile write helper stays removed', () {
    final repository = File(
      'lib/data/repositories/account_repository.dart',
    ).readAsStringSync();

    expect(repository, isNot(contains('_trySaveProfileOnline')));
  });
}
