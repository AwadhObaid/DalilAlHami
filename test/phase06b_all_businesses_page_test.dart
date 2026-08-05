import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/directory/all_businesses_page.dart';

import 'phase06b_test_harness.dart';

void main() {
  setUp(preparePhase06bData);

  testWidgets(
    'جميع الأنشطة تعرض البيانات وتبحث داخلها',
    (tester) async {
      await pumpPhase06bPage(
        tester,
        const AllBusinessesPage(),
      );

      expect(
        find.byKey(
          const ValueKey<String>('all-businesses-result-count'),
        ),
        findsOneWidget,
      );

      final field = find.byKey(
        const ValueKey<String>('all-businesses-search-field'),
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, 'مطعم');
      await tester.pumpAndSettle();

      expect(find.text('مطعم وادي سبأ'), findsOneWidget);
      expect(find.text('صيدلية الحامي الحديثة'), findsNothing);
      expectNoPhase06bException(tester);
    },
  );

  testWidgets(
    'فلتر النقل يعرض نشاط النقل فقط',
    (tester) async {
      await pumpPhase06bPage(
        tester,
        const AllBusinessesPage(),
      );

      await tapPhase06bControl(
        tester,
        find.byKey(
          const ValueKey<String>(
            'directory-filter-transport-businesses',
          ),
        ),
      );

      expect(find.text('تكتك السعيد'), findsOneWidget);
      expect(find.text('صيدلية الحامي الحديثة'), findsNothing);
      expectNoPhase06bException(tester);
    },
  );
}
