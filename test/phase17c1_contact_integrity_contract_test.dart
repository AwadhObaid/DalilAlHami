import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/business_contact_draft.dart';

void main() {
  group('Phase 17C.1 phone digit-count parity', () {
    BusinessContactDraft draft(String phone) => BusinessContactDraft(
          phoneNumber: phone,
          label: 'الرئيسي',
          isPrimary: true,
          supportsWhatsApp: false,
          sortOrder: 0,
        );

    test('accepts exactly 5 numeric digits', () {
      final values = BusinessContactDraft.normalizeAndValidate(
        <BusinessContactDraft>[draft('12-345')],
      );

      expect(values.single.phoneNumber, '12-345');
    });

    test('accepts exactly 20 numeric digits', () {
      const phone = '+12345678901234567890';
      final values = BusinessContactDraft.normalizeAndValidate(
        <BusinessContactDraft>[draft(phone)],
      );

      expect(
        BusinessContactDraft.normalizePhoneKey(values.single.phoneNumber)
            .replaceAll('+', '')
            .length,
        20,
      );
    });

    test('rejects fewer than 5 numeric digits', () {
      expect(
        () => BusinessContactDraft.normalizeAndValidate(
          <BusinessContactDraft>[draft('+12-34')],
        ),
        throwsA(isA<BusinessContactDraftValidationException>()),
      );
    });

    test('rejects more than 20 numeric digits', () {
      expect(
        () => BusinessContactDraft.normalizeAndValidate(
          <BusinessContactDraft>[
            draft('+123456789012345678901'),
          ],
        ),
        throwsA(isA<BusinessContactDraftValidationException>()),
      );
    });
  });

  test('Phase 17C.1 migration contains safe projection and postconditions',
      () async {
    final migration = await File(
      'supabase/migrations/20260815123254_phase17c1_contact_integrity_legacy_reconciliation.sql',
    ).readAsString();

    expect(
      migration,
      contains("set_config('dalil.contact_projection_write', 'on', true)"),
    );
    expect(
      migration,
      contains(
        "current_setting('dalil.contact_projection_write', true)",
      ),
    );
    expect(
      migration,
      contains('if projection_write then'),
    );
    expect(
      migration,
      contains('v_digit_count < 5'),
    );
    expect(
      migration,
      contains('v_digit_count > 20'),
    );
    expect(
      migration,
      contains('legacy projection mismatches remain'),
    );
    expect(
      migration,
      contains('normalized duplicate groups remain'),
    );
    expect(
      migration,
      contains('contact-count/primary/WhatsApp invariants'),
    );
  });
}
