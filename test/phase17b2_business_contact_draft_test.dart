import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/business_contact_draft.dart';
import 'package:hami_guide/models/business_contact_number.dart';

void main() {
  test('validates up to five contacts and derives legacy projections', () {
    final contacts = BusinessContactDraft.normalizeAndValidate(
      const <BusinessContactDraft>[
        BusinessContactDraft(
          phoneNumber: '05340080',
          label: 'الرئيسي',
          isPrimary: true,
          supportsWhatsApp: false,
          sortOrder: 0,
        ),
        BusinessContactDraft(
          phoneNumber: '773272911',
          label: 'جوال',
          isPrimary: false,
          supportsWhatsApp: true,
          sortOrder: 1,
        ),
        BusinessContactDraft(
          phoneNumber: '701591479',
          label: 'المبيعات',
          isPrimary: false,
          supportsWhatsApp: false,
          sortOrder: 2,
        ),
      ],
    );

    expect(contacts, hasLength(3));
    expect(BusinessContactDraft.primaryPhone(contacts), '05340080');
    expect(BusinessContactDraft.whatsappPhone(contacts), '773272911');
    expect(contacts.last.sortOrder, 2);
  });

  test('rejects duplicates, multiple primary, and multiple WhatsApp', () {
    expect(
      () => BusinessContactDraft.normalizeAndValidate(
        const <BusinessContactDraft>[
          BusinessContactDraft(
            phoneNumber: '777-123456',
            label: 'الرئيسي',
            isPrimary: true,
            supportsWhatsApp: false,
            sortOrder: 0,
          ),
          BusinessContactDraft(
            phoneNumber: '777123456',
            label: 'جوال',
            isPrimary: false,
            supportsWhatsApp: true,
            sortOrder: 1,
          ),
        ],
      ),
      throwsA(isA<BusinessContactDraftValidationException>()),
    );

    expect(
      () => BusinessContactDraft.normalizeAndValidate(
        const <BusinessContactDraft>[
          BusinessContactDraft(
            phoneNumber: '777111111',
            label: 'الرئيسي',
            isPrimary: true,
            supportsWhatsApp: false,
            sortOrder: 0,
          ),
          BusinessContactDraft(
            phoneNumber: '777222222',
            label: 'الإدارة',
            isPrimary: true,
            supportsWhatsApp: false,
            sortOrder: 1,
          ),
        ],
      ),
      throwsA(isA<BusinessContactDraftValidationException>()),
    );

    expect(
      () => BusinessContactDraft.normalizeAndValidate(
        const <BusinessContactDraft>[
          BusinessContactDraft(
            phoneNumber: '777111111',
            label: 'الرئيسي',
            isPrimary: true,
            supportsWhatsApp: true,
            sortOrder: 0,
          ),
          BusinessContactDraft(
            phoneNumber: '777222222',
            label: 'جوال',
            isPrimary: false,
            supportsWhatsApp: true,
            sortOrder: 1,
          ),
        ],
      ),
      throwsA(isA<BusinessContactDraftValidationException>()),
    );
  });

  test('reads normalized contacts first and preserves one WhatsApp', () {
    const contacts = <BusinessContactNumber>[
      BusinessContactNumber(
        id: 'a',
        businessId: 'b',
        phoneNumber: '05340080',
        label: 'الرئيسي',
        isPrimary: true,
      ),
      BusinessContactNumber(
        id: 'c',
        businessId: 'b',
        phoneNumber: '700750740',
        label: 'واتساب',
        supportsWhatsApp: true,
        sortOrder: 1,
      ),
    ];

    final drafts = BusinessContactDraft.fromExisting(
      contacts: contacts,
      legacyPhone: 'ignored',
      legacyWhatsApp: 'ignored',
    );

    expect(drafts, hasLength(2));
    expect(drafts.first.isPrimary, isTrue);
    expect(drafts.last.supportsWhatsApp, isTrue);
  });

  test('legacy save fallback keeps historic blank-WhatsApp behavior', () {
    final drafts = BusinessContactDraft.fromLegacyFields(
      legacyPhone: '777123456',
      legacyWhatsApp: '',
      defaultWhatsAppToPrimary: true,
    );
    expect(drafts, hasLength(1));
    expect(drafts.single.isPrimary, isTrue);
    expect(drafts.single.supportsWhatsApp, isTrue);
  });
}
