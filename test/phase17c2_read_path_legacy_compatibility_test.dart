import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/account_business.dart';
import 'package:hami_guide/models/admin_business_review.dart';
import 'package:hami_guide/models/admin_content_management.dart';
import 'package:hami_guide/models/business.dart';
import 'package:hami_guide/models/business_contact_number.dart';

BusinessContactNumber _contact({
  required String id,
  required String businessId,
  required String phone,
  bool primary = false,
  bool whatsapp = false,
  int order = 0,
}) {
  return BusinessContactNumber(
    id: id,
    businessId: businessId,
    phoneNumber: phone,
    label: primary ? 'الرئيسي' : 'جوال',
    isPrimary: primary,
    supportsWhatsApp: whatsapp,
    sortOrder: order,
  );
}

void main() {
  group('Phase 17C.2 read-path hardening', () {
    test('modern Business contacts override stale legacy projection', () {
      final business = Business(
        id: 'business-1',
        name: 'اختبار',
        phone: '111111111',
        whatsapp: '111111111',
        category: 'خدمات',
        place: 'الحامي',
        contactNumbers: <BusinessContactNumber>[
          _contact(
            id: 'c1',
            businessId: 'business-1',
            phone: '777000001',
            primary: true,
          ),
          _contact(
            id: 'c2',
            businessId: 'business-1',
            phone: '733000002',
            whatsapp: true,
            order: 1,
          ),
        ],
      );

      expect(business.phoneContact, '777000001');
      expect(business.whatsappContact, '733000002');
      expect(
        business.effectiveContactNumbers
            .map((item) => item.trimmedPhoneNumber)
            .toList(),
        <String>['777000001', '733000002'],
      );
      expect(business.matchesSearch('733000002'), isTrue);
      expect(
        business.matchesSearch('111111111'),
        isFalse,
        reason: 'Stale legacy projection must not override modern contacts.',
      );
    });

    test(
        'legacy fallback preserves Phase 17B.1 cardinality and WhatsApp action',
        () {
      final splitLegacy = Business(
        id: 'legacy-split',
        name: 'قديم',
        phone: '777100001',
        whatsapp: '733100002',
        category: 'خدمات',
        place: 'الحامي',
      );

      expect(splitLegacy.effectiveContactNumbers, hasLength(1));
      expect(
        splitLegacy.effectiveContactNumbers.single.trimmedPhoneNumber,
        '777100001',
      );
      expect(splitLegacy.phoneContact, '777100001');
      expect(splitLegacy.whatsappContact, '733100002');
      expect(splitLegacy.hasMultiplePhoneNumbers, isFalse);
      expect(splitLegacy.hasWhatsApp, isTrue);
      expect(splitLegacy.matchesSearch('733100002'), isTrue);

      final whatsappOnly = Business(
        id: 'legacy-wa-only',
        name: 'قديم',
        phone: '',
        whatsapp: '733100003',
        category: 'خدمات',
        place: 'الحامي',
      );

      expect(whatsappOnly.effectiveContactNumbers, isEmpty);
      expect(whatsappOnly.phoneContact, isEmpty);
      expect(whatsappOnly.whatsappContact, '733100003');
      expect(whatsappOnly.hasWhatsApp, isTrue);
      expect(whatsappOnly.matchesSearch('733100003'), isTrue);
    });

    test('AccountBusiness resolves modern contacts before legacy fields', () {
      final business = AccountBusiness(
        id: 'account-business',
        ownerId: 'owner',
        categoryId: 'category',
        categoryName: 'خدمات',
        name: 'نشاط',
        description: '',
        phone: '111111111',
        whatsapp: '111111111',
        address: 'الحامي',
        status: 'approved',
        isActive: true,
        contactNumbers: <BusinessContactNumber>[
          _contact(
            id: 'account-c1',
            businessId: 'account-business',
            phone: '777200001',
            primary: true,
          ),
          _contact(
            id: 'account-c2',
            businessId: 'account-business',
            phone: '733200002',
            whatsapp: true,
            order: 1,
          ),
        ],
      );

      expect(business.phoneContact, '777200001');
      expect(business.whatsappContact, '733200002');
      expect(business.contactSearchText, contains('733200002'));
      expect(business.contactSearchText, isNot(contains('111111111')));
    });

    test('admin management and review models expose modern read views', () {
      final now = DateTime.utc(2026, 8, 15);
      final contacts = <BusinessContactNumber>[
        _contact(
          id: 'admin-c1',
          businessId: 'admin-business',
          phone: '777300001',
          primary: true,
        ),
        _contact(
          id: 'admin-c2',
          businessId: 'admin-business',
          phone: '733300002',
          whatsapp: true,
          order: 1,
        ),
      ];

      final adminBusiness = AdminBusinessItem(
        id: 'admin-business',
        categoryId: 'category',
        categoryName: 'خدمات',
        name: 'نشاط إداري',
        description: '',
        phone: '111111111',
        whatsapp: '111111111',
        address: 'الحامي',
        status: 'approved',
        isFeatured: false,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        contactNumbers: contacts,
      );

      expect(adminBusiness.phoneContact, '777300001');
      expect(adminBusiness.whatsappContact, '733300002');
      expect(adminBusiness.contactSearchText, contains('733300002'));
      expect(adminBusiness.contactSearchText, isNot(contains('111111111')));

      final review = AdminBusinessReviewItem.fromMap(<String, dynamic>{
        'id': 'admin-business',
        'owner_id': 'owner',
        'category_id': 'category',
        'name': 'نشاط مراجعة',
        'description': '',
        'phone': '111111111',
        'whatsapp': '111111111',
        'address': 'الحامي',
        'status': 'pending',
        'is_featured': false,
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'categories': <String, dynamic>{'name_ar': 'خدمات'},
        'business_contact_numbers':
            contacts.map((item) => item.toMap()).toList(growable: false),
      });

      expect(review.phoneContact, '777300001');
      expect(review.whatsappContact, '733300002');
      expect(review.effectiveContactNumbers, hasLength(2));
    });

    test('Phase 17C.2 source contracts cover account/admin/review paths', () {
      final businessModel = File('lib/models/business.dart').readAsStringSync();
      final accountModel =
          File('lib/models/account_business.dart').readAsStringSync();
      final adminModel =
          File('lib/models/admin_content_management.dart').readAsStringSync();
      final reviewModel =
          File('lib/models/admin_business_review.dart').readAsStringSync();
      final adminRepository =
          File('lib/data/repositories/admin_repository.dart')
              .readAsStringSync();
      final ownedPage = File('lib/features/profile/owned_businesses_page.dart')
          .readAsStringSync();
      final profilePage =
          File('lib/features/profile/profile_page.dart').readAsStringSync();
      final adminPage =
          File('lib/features/admin/admin_business_management_page.dart')
              .readAsStringSync();
      final reviewPage =
          File('lib/features/admin/admin_business_review_page.dart')
              .readAsStringSync();
      final reviewDetail =
          File('lib/features/admin/admin_business_review_detail_page.dart')
              .readAsStringSync();

      expect(
          businessModel, contains('BusinessContactNumber.resolveEffective('));
      expect(
        businessModel,
        contains(
            "return legacyWhatsApp.isNotEmpty ? legacyWhatsApp : phoneContact;"),
      );
      expect(businessModel, isNot(contains('phone.contains(normalizedQuery)')));
      expect(
        businessModel,
        isNot(contains('whatsapp.contains(normalizedQuery)')),
      );
      expect(accountModel, contains('String get phoneContact'));
      expect(accountModel, contains('String get contactSearchText'));
      expect(adminModel, contains('String get contactSearchText'));
      expect(reviewModel, contains('business_contact_numbers'));
      expect(reviewModel, contains('effectiveContactNumbers'));

      expect(
        RegExp(r'business_contact_numbers\(')
            .allMatches(adminRepository)
            .length,
        greaterThanOrEqualTo(2),
      );
      expect(ownedPage, contains('business.phoneContact'));
      expect(profilePage, contains('business.effectiveContactNumbers'));
      expect(adminPage, contains('business.contactSearchText'));
      expect(adminPage, contains('business.phoneContact'));
      expect(reviewPage, contains('business.contactSearchText'));
      expect(reviewDetail, contains('_business.effectiveContactNumbers'));
    });
  });
}
