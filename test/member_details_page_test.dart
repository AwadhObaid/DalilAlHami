import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/directory/member_details_page.dart';
import 'package:hami_guide/models/business.dart';

void main() {
  testWidgets(
    'صفحة التفاصيل تعرض النشاط وأزرار التواصل دون تجاوز',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const business = Business(
        id: 'details-test',
        name: 'صيدلية الحامي الحديثة',
        phone: '777111222',
        category: 'صيدليات',
        place: 'بجانب المستشفى',
        details: 'صيدلية لخدمة أهالي مدينة الحامي.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const MemberDetailsPage(business: business),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('صيدلية الحامي الحديثة'), findsWidgets);
      expect(find.text('معلومات التواصل'), findsOneWidget);
      expect(find.text('اتصال الآن'), findsOneWidget);

      // يظهر واتساب في الإجراءات السريعة وفي الشريط السفلي.
      expect(find.text('واتساب'), findsNWidgets(2));
    },
  );

  testWidgets(
    'عناوين بطاقات التفاصيل تتحمل شاشة ضيقة وخطًا مكبرًا',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const business = Business(
        id: 'details-large-text-test',
        name: 'مركز الحامي للخدمات الطبية المتكاملة',
        phone: '777111222',
        whatsapp: '777111222',
        category: 'العيادات والمراكز الطبية المتخصصة',
        place: 'الشارع العام بجانب المستشفى المركزي',
        details: 'خدمات طبية متنوعة واستشارات ومتابعة للحالات.',
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 720),
            textScaler: TextScaler.linear(1.25),
          ),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const MemberDetailsPage(business: business),
          ),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('معلومات التواصل'), findsOneWidget);
      expect(find.text('نبذة عن النشاط'), findsOneWidget);
      expect(find.text('واتساب'), findsNWidgets(2));
    },
  );
}
