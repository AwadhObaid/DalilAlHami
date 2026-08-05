import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/search/directory_search_page.dart';

import 'phase06b_test_harness.dart';

void main() {
  setUp(preparePhase06bData);

  testWidgets(
    'البحث يعرض الاقتراحات ثم نتيجة النشاط المطابق',
    (tester) async {
      await pumpPhase06bPage(
        tester,
        const DirectorySearchPage(),
      );

      expect(
        find.byKey(const ValueKey<String>('search-prompt')),
        findsOneWidget,
      );
      expect(find.text('ما الذي تبحث عنه اليوم؟'), findsOneWidget);

      final field = find.byKey(
        const ValueKey<String>('directory-search-field'),
      );
      expect(field, findsOneWidget);

      await tester.enterText(field, 'صيدلية');
      await tester.pumpAndSettle();

      expect(find.text('صيدلية الحامي الحديثة'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('directory-search-result-count'),
        ),
        findsOneWidget,
      );
      expectNoPhase06bException(tester);
    },
  );

  testWidgets(
    'فلتر النقل يستبعد نتائج الخدمات',
    (tester) async {
      await pumpPhase06bPage(
        tester,
        const DirectorySearchPage(),
      );

      final field = find.byKey(
        const ValueKey<String>('directory-search-field'),
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, 'صيدلية');
      await tester.pump();

      await tapPhase06bControl(
        tester,
        find.byKey(
          const ValueKey<String>('directory-filter-transport'),
        ),
      );

      expect(find.text('صيدلية الحامي الحديثة'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('empty-search-results')),
        findsOneWidget,
      );
      expectNoPhase06bException(tester);
    },
  );

  testWidgets(
    'واجهة البحث تتحمل شاشة ضيقة وخطًا مكبرًا',
    (tester) async {
      await pumpPhase06bPage(
        tester,
        const DirectorySearchPage(),
        size: const Size(320, 720),
        textScale: 1.35,
      );

      expect(
        find.byKey(
          const ValueKey<String>('directory-search-page-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('directory-search-header')),
        findsOneWidget,
      );
      expectNoPhase06bException(tester);
    },
  );

  testWidgets(
    'البحث يبقى قابلًا للاستخدام مع ظهور لوحة المفاتيح',
    (tester) async {
      await pumpPhase06bPage(
        tester,
        const DirectorySearchPage(),
        size: const Size(320, 720),
        textScale: 1.25,
        keyboardInset: 300,
      );

      expect(
        find.byKey(const ValueKey<String>('directory-search-header')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('directory-search-field')),
        findsOneWidget,
      );
      expectNoPhase06bException(tester);
    },
  );
}
