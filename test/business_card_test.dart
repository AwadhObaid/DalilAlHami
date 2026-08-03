import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/directory/widgets/business_card.dart';
import 'package:hami_guide/models/business.dart';

void main() {
  testWidgets('بطاقة النشاط لا تتجاوز الشاشة الضيقة', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const business = Business(
      id: 'business-card-test',
      name: 'مطعم وادي الحامي للمأكولات الشعبية',
      phone: '777123456',
      whatsapp: '777123456',
      category: 'مطاعم',
      place: 'الشارع العام بجانب السوق',
      details: 'وجبات شعبية ومأكولات متنوعة للعائلات.',
      isFeatured: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: BusinessCard(
              business: business,
              onOpen: _emptyCallback,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('اتصال'), findsOneWidget);
    expect(find.text('واتساب'), findsOneWidget);
    expect(find.textContaining('مطعم وادي الحامي'), findsOneWidget);
  });
}

void _emptyCallback() {}
