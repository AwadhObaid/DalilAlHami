import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/directory/categories_overview_page.dart';
import 'package:hami_guide/features/directory/category_list_page.dart';

import 'phase06b_test_harness.dart';

void main() {
  setUp(preparePhase06bData);

  testWidgets(
    'تبديل المجموعة يعرض أقسام النقل',
    (tester) async {
      await pumpPhase06bPage(
        tester,
        const CategoriesOverviewPage(),
      );

      await tapPhase06bControl(
        tester,
        find.byKey(
          const ValueKey<String>('category-group-transport'),
        ),
      );

      expect(find.text('تكاتك'), findsOneWidget);
      expect(find.text('سيارات نقل'), findsOneWidget);
      expectNoPhase06bException(tester);
    },
  );

  testWidgets(
    'البحث داخل الأقسام يفتح قائمة القسم المختار',
    (tester) async {
      await pumpPhase06bPage(
        tester,
        const CategoriesOverviewPage(),
      );

      final field = find.byKey(
        const ValueKey<String>('category-search-field'),
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, 'مطاعم');
      await tester.pumpAndSettle();

      final card = find.byKey(
        const ValueKey<String>('category-card-local-restaurants'),
      );
      expect(card, findsOneWidget);

      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryListPage), findsOneWidget);
      expect(find.text('مطاعم'), findsWidgets);
      expectNoPhase06bException(tester);
    },
  );

  testWidgets(
    'صفحة الأقسام مستقلة وتتحمل الشاشة الضيقة والخط المكبر',
    (tester) async {
      await pumpPhase06bPage(
        tester,
        const CategoriesOverviewPage(),
        size: const Size(320, 720),
        textScale: 1.35,
      );

      expect(
        find.byKey(
          const ValueKey<String>('categories-overview-page-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('category-search-field')),
        findsOneWidget,
      );
      expectNoPhase06bException(tester);
    },
  );
}
