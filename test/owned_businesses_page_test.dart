import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/profile/owned_businesses_page.dart';
import 'package:hami_guide/models/account_business.dart';

void main() {
  testWidgets('بطاقة النشاط تفتح إدارة النشاط المحدد', (tester) async {
    var opened = false;
    const business = AccountBusiness(
      id: 'business-2',
      ownerId: 'user-1',
      categoryId: 'category-1',
      categoryName: 'مطاعم',
      name: 'النشاط الثاني',
      description: '',
      phone: '777000000',
      whatsapp: '777000000',
      address: 'الحامي',
      status: 'pending',
      isActive: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OwnedBusinessCard(
            business: business,
            onPressed: () {
              opened = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('النشاط الثاني'), findsOneWidget);
    expect(find.text('قيد المراجعة'), findsOneWidget);
    await tester.tap(find.text('إدارة النشاط'));
    await tester.pump();
    expect(opened, isTrue);
  });
}
