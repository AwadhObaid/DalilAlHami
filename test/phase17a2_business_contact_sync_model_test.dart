import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/business.dart';
import 'package:hami_guide/models/business_contact_number.dart';

void main() {
  test('contact model preserves sync metadata and filters deleted rows', () {
    final contacts = BusinessContactNumber.readList([
      {
        'id': 'primary',
        'business_id': 'business-1',
        'phone_number': '777111222',
        'label': 'الرئيسي',
        'is_primary': true,
        'supports_whatsapp': false,
        'sort_order': 0,
        'sync_version': 101,
      },
      {
        'id': 'deleted',
        'business_id': 'business-1',
        'phone_number': '700000000',
        'sort_order': 1,
        'deleted_at': '2026-08-14T16:00:00Z',
        'sync_version': 102,
      },
      {
        'id': 'whatsapp',
        'business_id': 'business-1',
        'phone_number': '733444555',
        'label': 'واتساب',
        'supports_whatsapp': true,
        'sort_order': 2,
        'sync_version': 103,
      },
    ]);

    expect(contacts, hasLength(2));
    expect(contacts.first.id, 'primary');
    expect(contacts.first.syncVersion, 101);
    expect(contacts.last.id, 'whatsapp');
    expect(contacts.last.supportsWhatsApp, isTrue);
  });

  test('Business.fromSupabase maps nested multiple contact numbers', () {
    final business = Business.fromSupabase({
      'id': 'business-1',
      'category_id': 'category-1',
      'name': 'نشاط متعدد الأرقام',
      'phone': '777111222',
      'whatsapp': '733444555',
      'address': 'الحامي',
      'sync_version': 103,
      'categories': {
        'id': 'category-1',
        'name_ar': 'خدمات',
        'slug': 'services',
        'icon_name': 'storefront',
      },
      'business_contact_numbers': [
        {
          'id': 'phone-2',
          'business_id': 'business-1',
          'phone_number': '733444555',
          'label': 'واتساب',
          'is_primary': false,
          'supports_whatsapp': true,
          'sort_order': 1,
          'sync_version': 103,
        },
        {
          'id': 'phone-1',
          'business_id': 'business-1',
          'phone_number': '777111222',
          'label': 'الرئيسي',
          'is_primary': true,
          'supports_whatsapp': false,
          'sort_order': 0,
          'sync_version': 102,
        },
      ],
    });

    expect(business.contactNumbers, hasLength(2));
    expect(business.contactNumbers.first.phoneNumber, '777111222');
    expect(business.contactNumbers.first.isPrimary, isTrue);
    expect(business.contactNumbers.last.supportsWhatsApp, isTrue);
  });
}
