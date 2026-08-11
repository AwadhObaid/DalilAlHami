import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AccountHub resets and fences state by authenticated user ID', () {
    final source =
        File('lib/features/profile/account_hub_page.dart').readAsStringSync();

    expect(source, contains('String? _activeUserId;'));
    expect(source, contains('String? _ownedBusinessRequestUserId;'));
    expect(source, contains('_activeUserId = _authStore.user?.id;'));
    expect(source, contains('final currentUserId = _authStore.user?.id;'));
    expect(source, contains('if (_activeUserId != currentUserId)'));
    expect(source, contains('_ownedBusinessCount = null;'));
    expect(source, contains('_accountProfile = _authStore.accountProfile;'));
    expect(source, contains('final requestedUserId = _authStore.user?.id;'));
    expect(
      source,
      contains('_ownedBusinessRequestUserId == requestedUserId'),
    );
    expect(
      source,
      contains('_authStore.user?.id != requestedUserId'),
    );
    expect(
      source,
      contains('snapshot.profile.id != requestedUserId'),
    );
  });

  test('Manage Business clears old form data on account identity change', () {
    final source =
        File('lib/features/profile/profile_page.dart').readAsStringSync();

    expect(source, contains('String? _activeUserId;'));
    expect(source, contains('String? _loadRequestUserId;'));
    expect(source, contains('_activeUserId = _authStore.user?.id;'));
    expect(source, contains('if (_activeUserId == currentUserId)'));
    expect(source, contains('_profile = null;'));
    expect(source, contains('_business = null;'));
    expect(source, contains('_businessNameController.clear();'));
    expect(source, contains('_phoneController.clear();'));
    expect(source, contains('_whatsappController.clear();'));
    expect(source, contains("_addressController.text = 'الحامي';"));
    expect(source, contains('_descriptionController.clear();'));
  });

  test('Manage Business account load rejects stale user results', () {
    final source =
        File('lib/features/profile/profile_page.dart').readAsStringSync();

    expect(source, contains('final requestedUserId = _authStore.user?.id;'));
    expect(source, contains('_loadRequestUserId == requestedUserId'));
    expect(
      source,
      contains('_authStore.user?.id != requestedUserId'),
    );
    expect(
      source,
      contains('snapshot.profile.id != requestedUserId'),
    );
    expect(source, contains('_loadRequestUserId = null;'));
  });

  test('Phase 14 signed-out queue banner protection remains intact', () {
    final source =
        File('lib/features/profile/profile_page.dart').readAsStringSync();

    expect(
      source,
      contains(
        'if (_authStore.isAuthenticated &&\n'
        '              (_directoryStore.pendingSyncOperationCount > 0 ||',
      ),
    );
  });
}
