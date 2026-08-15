import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 17B.2 wires user/admin multi-contact management safely', () {
    final profile =
        File('lib/features/profile/profile_page.dart').readAsStringSync();
    final account = File('lib/data/repositories/account_repository.dart')
        .readAsStringSync();
    final gateway = File(
      'lib/data/sync_queue/supabase_sync_queue_gateway.dart',
    ).readAsStringSync();
    final adminForm = File('lib/features/admin/admin_business_form_page.dart')
        .readAsStringSync();
    final adminRepo =
        File('lib/data/repositories/admin_content_repository.dart')
            .readAsStringSync();
    final database = File(
      'lib/data/local/database/local_directory_database.dart',
    ).readAsStringSync();
    final hardening = File(
      'supabase/migrations/'
      '20260814213329_phase17b2_harden_multi_contact_mutations.sql',
    ).readAsStringSync();

    expect(profile, contains('BusinessContactEditor'));

    expect(
      account,
      matches(
        RegExp(
          r"'contact_numbers'\s*:\s*normalizedContacts",
          multiLine: true,
        ),
      ),
    );
    expect(
      account,
      matches(
        RegExp(
          r'contactNumbers\s*:\s*'
          r'(?:List<BusinessContactNumber>\.unmodifiable\s*\(\s*)?'
          r'localContacts\s*\)?',
          multiLine: true,
        ),
      ),
    );

    expect(gateway, contains('process_directory_sync_operation_v2'));
    expect(adminForm, contains('BusinessContactEditor'));
    expect(adminRepo, contains('admin_upsert_business_v2'));
    expect(adminRepo, contains('business_contact_numbers('));

    expect(
      database,
      matches(RegExp(r'schemaVersion\s*=\s*13')),
    );
    expect(database, contains('contact_numbers_json'));

    expect(
      hardening,
      matches(
        RegExp(
          r"v_legacy_payload\s*:=\s*"
          r"v_legacy_payload\s*-\s*'phone'\s*-\s*'whatsapp'",
          multiLine: true,
        ),
      ),
    );
    expect(
      hardening,
      matches(RegExp(r'v_whatsapp_count\s*>\s*1')),
    );
    expect(
      hardening,
      matches(RegExp(r'local_payload\s*=\s*p_payload')),
    );
  });
}
