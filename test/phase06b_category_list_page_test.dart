import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/directory/category_list_page.dart';

import 'phase06b_test_harness.dart';

void main() {
  setUp(preparePhase06bData);

  testWidgets(
    'قائمة القسم تعرض نشاطه وتدعم البحث الداخلي',
    (tester) async {
      await pumpPhase06bPage(
        tester,
        const CategoryListPage(
          categoryName: 'مطاعم',
          categoryId: 'local-restaurants',
          categoryIcon: Icons.restaurant_rounded,
        ),
      );

      expect(find.text('مطعم وادي سبأ'), findsOneWidget);

      final field = find.byKey(
        const ValueKey<String>('category-list-search-field'),
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, 'غير موجود');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('empty-category-state')),
        findsOneWidget,
      );
      expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);
      expectNoPhase06bException(tester);
    },
  );

  testWidgets(
    'قائمة القسم تتحمل شاشة ضيقة وخطًا مكبرًا',
    (tester) async {
      await pumpPhase06bPage(
        tester,
        const CategoryListPage(
          categoryName: 'مطاعم',
          categoryId: 'local-restaurants',
          categoryIcon: Icons.restaurant_rounded,
        ),
        size: const Size(320, 720),
        textScale: 1.35,
      );

      expect(
        find.byKey(const ValueKey<String>('category-list-page-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('category-list-header')),
        findsOneWidget,
      );
      expectNoPhase06bException(tester);
    },
  );
}
