import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/directory/all_businesses_page.dart';

import 'phase06a_test_harness.dart';

void main() {
  setUpAll(preparePhase06aDirectoryData);

  testWidgets(
    'عرض الكل للأنشطة القريبة يفتح قائمة جميع الأنشطة',
    (tester) async {
      await pumpPhase06aHome(tester);

      final button = find.byKey(
        const ValueKey<String>('nearby-businesses-view-all'),
      );

      await dragHomeUntilBuilt(
        tester,
        button,
        distance: 260,
      );

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.byType(AllBusinessesPage), findsOneWidget);
      expect(find.text('جميع الأنشطة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'المساحة المتبقية تعرض بطاقة استكشاف الدليل',
    (tester) async {
      await pumpPhase06aHome(
        tester,
        size: const Size(360, 900),
      );

      final footer = find.byKey(
        const ValueKey<String>('home-explore-directory-footer'),
      );

      await dragHomeUntilBuilt(
        tester,
        footer,
        distance: 420,
        maxDrags: 20,
      );

      expect(footer, findsOneWidget);
      expect(find.text('استكشف دليل الحامي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
