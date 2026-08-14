import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/business.dart';
import 'package:hami_guide/models/business_contact_number.dart';

void main() {
  const normalizedBusiness = Business(
    id: 'business-1',
    name: 'نشاط متعدد الأرقام',
    phone: '700000000',
    whatsapp: '711111111',
    category: 'خدمات',
    place: 'الحامي',
    contactNumbers: <BusinessContactNumber>[
      BusinessContactNumber(
        id: 'contact-primary',
        businessId: 'business-1',
        phoneNumber: '05340080',
        label: 'الرئيسي',
        isPrimary: true,
        sortOrder: 0,
      ),
      BusinessContactNumber(
        id: 'contact-whatsapp',
        businessId: 'business-1',
        phoneNumber: '773272911',
        label: 'جوال',
        supportsWhatsApp: true,
        sortOrder: 1,
      ),
      BusinessContactNumber(
        id: 'contact-sales',
        businessId: 'business-1',
        phoneNumber: '701591479',
        label: 'المبيعات',
        sortOrder: 2,
      ),
    ],
  );

  test('normalized contacts drive call and WhatsApp presentation', () {
    expect(normalizedBusiness.effectiveContactNumbers, hasLength(3));
    expect(normalizedBusiness.phoneContact, '05340080');
    expect(normalizedBusiness.hasPhone, isTrue);
    expect(normalizedBusiness.hasMultiplePhoneNumbers, isTrue);
    expect(
      normalizedBusiness.whatsappContactNumber?.trimmedPhoneNumber,
      '773272911',
    );
    expect(normalizedBusiness.whatsappContact, '773272911');
    expect(normalizedBusiness.hasWhatsApp, isTrue);
    expect(normalizedBusiness.matchesSearch('701591479'), isTrue);
  });

  test(
      'legacy fields remain a safe fallback when normalized contacts are absent',
      () {
    const legacyBusiness = Business(
      id: 'legacy-business',
      name: 'نشاط قديم',
      phone: '777000111',
      whatsapp: '733000222',
      category: 'خدمات',
      place: 'الحامي',
    );

    expect(legacyBusiness.effectiveContactNumbers, hasLength(1));
    expect(
      legacyBusiness.effectiveContactNumbers.single.trimmedPhoneNumber,
      '777000111',
    );
    expect(legacyBusiness.phoneContact, '777000111');
    expect(legacyBusiness.whatsappContact, '733000222');
    expect(legacyBusiness.hasMultiplePhoneNumbers, isFalse);
  });

  test('legacy phone remains WhatsApp fallback when legacy WhatsApp is empty',
      () {
    const legacyBusiness = Business(
      id: 'legacy-business-2',
      name: 'نشاط قديم',
      phone: '777000333',
      category: 'خدمات',
      place: 'الحامي',
    );

    expect(legacyBusiness.whatsappContact, '777000333');
    expect(legacyBusiness.hasWhatsApp, isTrue);
  });
}
