import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

    expect(accountHub, contains('_accountProfile?.isAdmin == true'));
    expect(accountHub, contains('AdminDashboardEntryCard'));
    expect(adminPage, contains('!profile.isActive || !profile.isAdmin'));
    expect(adminRepository, contains(".from('profiles')"));
    expect(adminRepository, contains('AdminAccessDenied'));
    expect(accountRepository, contains("role: cachedProfile?.role ?? 'user'"));
  });
}
