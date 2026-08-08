import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 12A account access changes are refreshed and enforced', () {
    final localization = File(
      'lib/core/localization/app_localized_text.dart',
    ).readAsStringSync();
    final authStore = File(
      'lib/core/services/auth_session_store.dart',
    ).readAsStringSync();
    final home = File(
      'lib/features/home/home_screen.dart',
    ).readAsStringSync();
    final accountHub = File(
      'lib/features/profile/account_hub_page.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/data/repositories/admin_user_repository.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/models/account_profile.dart',
    ).readAsStringSync();

    expect(localization, contains('soft-deleted by an administrator'));
    expect(authStore, contains('refreshAccountProfile({bool force = false})'));
    expect(authStore, contains('AppLifecycleState.resumed'));
    expect(authStore, contains(".from('profiles')"));
    expect(home, contains('_accountRefreshSignal'));
    expect(home, contains('refreshAccountProfile(force: true)'));
    expect(home, contains('AccountSuspendedFailure(liveProfile)'));
    expect(accountHub, contains('widget.refreshSignal'));
    expect(accountHub, contains('_authStore.accountProfile'));
    expect(repository, contains('result.profileIsActive != isActive'));
    expect(repository, contains('result.profileIsDeleted != isDeleted'));
    expect(repository, contains('result.profileRole?.trim().toLowerCase()'));
    expect(profile, contains('bool get isDeleted => deletedAt != null;'));
    expect(
        profile, contains('bool get canUseAccount => isActive && !isDeleted;'));
  });
}
