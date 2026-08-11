import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile phone survives Google metadata-only auth updates', () {
    final migration = File(
      'supabase/migrations/20260811152000_phase14a_profile_phone_persistence_fix.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains(
        "when nullif(btrim(coalesce(excluded.phone, '')), '') is null",
      ),
    );
    expect(migration, contains('then public.profiles.phone'));
    expect(migration, contains('else excluded.phone'));
    expect(
      migration,
      contains(
        'after insert or update of email, phone, raw_user_meta_data',
      ),
    );
  });

  test('account profile still writes the entered phone directly to profiles',
      () {
    final repository = File(
      'lib/data/repositories/account_repository.dart',
    ).readAsStringSync();

    expect(repository, contains('required String phone'));
    expect(
      repository,
      contains('final normalizedPhone = phone.trim();'),
    );
    expect(repository, contains("'phone': normalizedPhone"));
    expect(repository, contains('_client.auth.updateUser'));
  });

  test('business edit header no longer renders the small camera icon', () {
    final page = File(
      'lib/features/profile/profile_page.dart',
    ).readAsStringSync();

    expect(page, isNot(contains('Icons.camera_alt')));
    expect(
      page,
      contains(
        "key: const ValueKey<String>('business-header-logo')",
      ),
    );
    expect(
      page,
      contains('onTap: isEditable && !_isSaving ? _pickImage : null'),
    );
  });
}
