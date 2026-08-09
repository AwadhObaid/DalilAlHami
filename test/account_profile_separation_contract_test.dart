import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account identity is separated from owned business editing', () {
    final hub =
        File('lib/features/profile/account_hub_page.dart').readAsStringSync();
    final accountProfile = File(
      'lib/features/profile/account_profile_page.dart',
    ).readAsStringSync();
    final businessProfile =
        File('lib/features/profile/profile_page.dart').readAsStringSync();
    final repository = File(
      'lib/data/repositories/account_repository.dart',
    ).readAsStringSync();

    expect(hub, contains('AccountProfilePage'));
    expect(hub, contains("'بيانات الحساب'"));
    expect(hub, contains("'إدارة أنشطتي'"));

    expect(accountProfile, contains("'account-profile-page'"));
    expect(accountProfile, contains("'account-profile-full-name'"));
    expect(accountProfile, contains("'account-profile-phone'"));
    expect(accountProfile, contains("'account-profile-email'"));
    expect(accountProfile, contains("'account-profile-change-avatar'"));
    expect(accountProfile, contains("'account-profile-delete-avatar'"));
    expect(accountProfile, contains("'account-profile-save'"));

    expect(businessProfile, isNot(contains("'بيانات الحساب'")));
    expect(businessProfile, isNot(contains("'الاسم الشخصي'")));
    expect(businessProfile, isNot(contains('profile-avatar-editor')));
    expect(businessProfile, contains("'تفاصيل النشاط'"));
    expect(businessProfile, contains('_buildHeaderImage(isEditable: true)'));

    expect(repository, contains('updateProfileDetails'));
    expect(repository, contains('clearProfileAvatar'));
    expect(repository, contains('Future<AccountSaveResult> saveAccount({'));
    expect(
      repository,
      isNot(contains('required String fullName,\n    required String categoryId')),
    );
  });

  test('multiple businesses remain independently addressable', () {
    final owned = File(
      'lib/features/profile/owned_businesses_page.dart',
    ).readAsStringSync();
    final businessProfile =
        File('lib/features/profile/profile_page.dart').readAsStringSync();

    expect(owned, contains('snapshot.allBusinesses'));
    expect(owned, contains('ProfilePage(businessId: business.id)'));
    expect(owned, contains('يمكنك إضافة أكثر من نشاط'));
    expect(businessProfile, contains('this.businessId'));
    expect(businessProfile, contains('preferredBusinessId: widget.businessId'));
  });
}
