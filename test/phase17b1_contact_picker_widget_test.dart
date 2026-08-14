import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/shared/utils/business_contact_actions.dart';
import 'package:hami_guide/models/business.dart';
import 'package:hami_guide/models/business_contact_number.dart';

void main() {
  const business = Business(
    id: 'picker-business',
    name: 'نشاط متعدد',
    phone: 'legacy',
    category: 'خدمات',
    place: 'الحامي',
    contactNumbers: <BusinessContactNumber>[
      BusinessContactNumber(
        id: 'primary',
        businessId: 'picker-business',
        phoneNumber: '05340080',
        label: 'الرئيسي',
        isPrimary: true,
        sortOrder: 0,
      ),
      BusinessContactNumber(
        id: 'mobile',
        businessId: 'picker-business',
        phoneNumber: '773272911',
        label: 'جوال',
        supportsWhatsApp: true,
        sortOrder: 1,
      ),
      BusinessContactNumber(
        id: 'sales',
        businessId: 'picker-business',
        phoneNumber: '701591479',
        label: 'المبيعات',
        sortOrder: 2,
      ),
    ],
  );

  test('multiple normalized phone numbers require a picker', () {
    expect(BusinessContactActions.requiresPhonePicker(business), isTrue);
  });

  testWidgets('call action shows every contact and renders numbers LTR',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const ValueKey<String>('open-contact-picker'),
                  onPressed: () {
                    BusinessContactActions.call(context, business);
                  },
                  child: const Text('فتح'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-contact-picker')));
    await tester.pumpAndSettle();

    expect(find.text('اختر رقم الاتصال'), findsOneWidget);
    expect(find.text('05340080'), findsOneWidget);
    expect(find.text('773272911'), findsOneWidget);
    expect(find.text('701591479'), findsOneWidget);
    expect(find.text('الرئيسي'), findsOneWidget);
    expect(find.text('جوال'), findsOneWidget);
    expect(find.text('المبيعات'), findsOneWidget);
    expect(find.text('واتساب'), findsOneWidget);

    final phoneText = tester.widget<Text>(
      find.byKey(
        const ValueKey<String>('business-contact-picker-number-mobile'),
      ),
    );
    expect(phoneText.textDirection, TextDirection.ltr);
  });
}
