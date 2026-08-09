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
  test('الدخول الإداري مشروط بالدور ويُعاد التحقق منه داخل الصفحة', () {
    final accountHub = File(
      'lib/features/profile/account_hub_page.dart',
    ).readAsStringSync();
    final adminPage = File(
      'lib/features/admin/admin_dashboard_page.dart',
    ).readAsStringSync();
    final adminRepository = File(
      'lib/data/repositories/admin_repository.dart',
    ).readAsStringSync();
    final accountRepository = File(
      'lib/data/repositories/account_repository.dart',
    ).readAsStringSync();

    final saveBusiness = _slice(
      accountRepository,
      'Future<AccountSaveResult> saveAccount({',
      'Future<AccountDeleteResult> deleteOwnedBusiness(',
    );
    final profileFallback = _slice(
      accountRepository,
      'AccountProfile _profileFromUser(User user) {',
      'String _createUuidV4() {',
    );

    expect(accountHub, contains('_accountProfile?.isAdmin == true'));
    expect(accountHub, contains('AdminDashboardEntryCard'));
    expect(adminPage, contains('!profile.isActive || !profile.isAdmin'));
    expect(adminRepository, contains(".from('profiles')"));
    expect(adminRepository, contains('AdminAccessDenied'));

    // After separating personal account data from business editing, saveAccount
    // no longer rebuilds AccountProfile. It preserves the cached profile
    // (including an admin role) and only falls back to a normal user profile
    // when no cached profile exists.
    expect(
      saveBusiness,
      contains('final profile = cachedProfile ?? _profileFromUser(user);'),
    );
    expect(profileFallback, contains("role: 'user'"));
  });
}
