import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
      'supabase/migrations/20260814162027_business_contact_numbers_foundation.sql');
  final model = File('lib/models/business_contact_number.dart');
  final repository =
      File('lib/data/repositories/business_contact_number_repository.dart');

  test('Phase 17A.1 migration preserves legacy compatibility', () {
    final sql = migration.readAsStringSync();
    expect(sql,
        contains('create table if not exists public.business_contact_numbers'));
    expect(sql, contains('business_contact_numbers_one_primary_idx'));
    expect(
        sql, contains('A business can have at most 5 active contact numbers.'));
    expect(sql, contains('split_legacy_business_phone_numbers'));
    expect(sql, contains('refresh_business_legacy_contact_fields'));
    expect(sql, contains('sync_legacy_business_fields_to_contacts'));
    expect(sql, contains('pg_trigger_depth() > 1'));
    expect(sql, contains('business_contact_numbers_after_change_trigger'));
    expect(sql, contains("set status = 'pending'"));
    expect(sql, contains('No bulk rewrite of businesses.phone'));
    expect(sql, isNot(contains('drop column phone')));
    expect(sql, isNot(contains('drop column whatsapp')));
  });

  test('internal contact helpers are not public RPC functions', () {
    final hardening = File(
      'supabase/migrations/'
      '20260814162245_harden_business_contact_numbers_internal_functions.sql',
    ).readAsStringSync();

    expect(
      hardening,
      contains(
        'revoke all on function public.enforce_business_contact_number_limit()',
      ),
    );
    expect(
      hardening,
      contains(
        'revoke all on function public.business_contact_numbers_after_change_trigger()',
      ),
    );
    expect(hardening, contains('from public, anon, authenticated'));
  });
  test('contact model and repository expose multi-number contract', () {
    final modelSource = model.readAsStringSync();
    final repositorySource = repository.readAsStringSync();
    expect(modelSource, contains('static const int maxPerBusiness = 5'));
    expect(modelSource, contains('supportsWhatsApp'));
    expect(modelSource, contains('isPrimary'));
    expect(modelSource, contains('sortOrder'));
    expect(repositorySource, contains("from('business_contact_numbers')"));
    expect(repositorySource, contains("inFilter('business_id', ids)"));
    expect(repositorySource, contains("isFilter('deleted_at', null)"));
  });
}
