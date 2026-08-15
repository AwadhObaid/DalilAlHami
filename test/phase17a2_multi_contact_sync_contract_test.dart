import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 17A.2 wires contacts into sync and offline cache', () {
    final business = File('lib/models/business.dart').readAsStringSync();
    final contact =
        File('lib/models/business_contact_number.dart').readAsStringSync();
    final database = File(
      'lib/data/local/database/local_directory_database.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/data/repositories/supabase_directory_repository.dart',
    ).readAsStringSync();
    final syncSql = File(
      'supabase/migrations/'
      '20260814171945_business_contact_numbers_directory_sync.sql',
    ).readAsStringSync();
    final hardeningSql = File(
      'supabase/migrations/'
      '20260814172015_harden_business_contact_number_delete_sync.sql',
    ).readAsStringSync();

    expect(
      business,
      contains('final List<BusinessContactNumber> contactNumbers;'),
    );
    expect(business, contains('BusinessContactNumber.readList('));
    expect(business, contains("data['business_contact_numbers']"));

    expect(contact, contains('final int syncVersion;'));
    expect(contact, contains('final DateTime? deletedAt;'));
    expect(contact, contains('Map<String, dynamic> toMap()'));

    // Phase 17B.2 advances the current SQLite schema to 13 for the owned
    // business contact cache. The Phase 17A.2 recovery contract itself must
    // still remain present as the oldVersion < 12 migration block.
    expect(database, contains('schemaVersion = 13'));
    expect(database, contains('if (oldVersion < 12)'));
    expect(database, contains('Phase 17A.2 recovery:'));
    expect(database, contains('contact_numbers_json'));
    expect(repository, contains('business_contact_numbers('));

    expect(syncSql, contains('touch_business_contact_number_sync_row'));
    expect(
      syncSql,
      contains('business_contact_numbers_directory_sync_touch'),
    );
    expect(
      syncSql,
      contains(
        'coalesce((select max(sync_version) '
        'from public.business_contact_numbers), 0)',
      ),
    );
    expect(
      syncSql,
      contains("'business_contact_numbers', contacts.contact_numbers"),
    );
    expect(syncSql, contains('contacts.sync_version'));
    expect(
      syncSql,
      contains(
        'revoke all\n'
        '  on function public.touch_business_contact_number_sync_row()\n'
        '  from public, anon, authenticated;',
      ),
    );

    expect(
      hardeningSql,
      contains('bump_business_sync_after_contact_delete'),
    );
    expect(
      hardeningSql,
      contains('business_contact_numbers_directory_sync_delete'),
    );
    expect(
      hardeningSql,
      contains("set updated_at = timezone('utc', now())"),
    );
    expect(
      hardeningSql,
      contains(
        'revoke all\n'
        '  on function public.bump_business_sync_after_contact_delete()\n'
        '  from public, anon, authenticated;',
      ),
    );
  });
}
