import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/directory/categories_overview_page.dart';

import 'phase06a_test_harness.dart';

void main() {
  setUpAll(preparePhase06aDirectoryData);

  testWidgets(
    'عرض الكل في الفئات المميزة يفتح صفحة الأقسام',
    (tester) async {
      await pumpPhase06aHome(
        tester,
        size: const Size(360, 900),
      );

      final button = find.byKey(
        const ValueKey<String>('featured-categories-view-all'),
      );

      await dragHomeUntilBuilt(
        tester,
        button,
        distance: 220,
      );

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.byType(CategoriesOverviewPage), findsOneWidget);
      expect(find.text('الأقسام'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
