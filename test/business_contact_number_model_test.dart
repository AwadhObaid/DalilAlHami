import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/business_contact_number.dart';

void main() {
  group('BusinessContactNumber', () {
    test('maps Supabase contact metadata', () {
      final item = BusinessContactNumber.fromSupabase({
        'id': 'contact-1',
        'business_id': 'business-1',
        'phone_number': ' 773272911 ',
        'label': 'المبيعات',
        'is_primary': true,
        'supports_whatsapp': true,
        'sort_order': 2,
        'created_at': '2026-08-14T12:00:00Z',
        'updated_at': '2026-08-14T13:00:00Z',
      });
      expect(item.id, 'contact-1');
      expect(item.businessId, 'business-1');
      expect(item.trimmedPhoneNumber, '773272911');
      expect(item.displayLabel, 'المبيعات');
      expect(item.isPrimary, isTrue);
      expect(item.supportsWhatsApp, isTrue);
      expect(item.sortOrder, 2);
      expect(item.createdAt, DateTime.utc(2026, 8, 14, 12));
    });

    test('uses safe fallback labels', () {
      const primary = BusinessContactNumber(
        id: '1',
        businessId: 'b',
        phoneNumber: '1',
        isPrimary: true,
      );
      const secondary = BusinessContactNumber(
        id: '2',
        businessId: 'b',
        phoneNumber: '2',
      );
      expect(primary.displayLabel, 'الرئيسي');
      expect(secondary.displayLabel, 'رقم الاتصال');
      expect(BusinessContactNumber.maxPerBusiness, 5);
    });
  });
}
