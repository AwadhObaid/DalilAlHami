import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/directory/all_businesses_page.dart';
import 'package:hami_guide/features/directory/categories_overview_page.dart';
import 'package:hami_guide/features/directory/category_list_page.dart';
import 'package:hami_guide/features/search/directory_search_page.dart';
import 'package:hami_guide/features/shared/widgets/directory_filter_bar.dart';
import 'package:hami_guide/features/shared/widgets/directory_search_field.dart';

import 'phase06b_test_harness.dart';

void main() {
  setUp(preparePhase06bData);

  testWidgets(
    'مكونات البحث والفلاتر توفر Material وتتحمل الخط المكبر',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 260));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = TextEditingController();
      addTearDown(controller.dispose);

      const options = [
        DirectoryFilterOption(
          id: 'one',
          label: 'الأول',
          icon: Icons.looks_one_rounded,
        ),
        DirectoryFilterOption(
          id: 'two',
          label: 'الثاني',
          icon: Icons.looks_two_rounded,
        ),
        DirectoryFilterOption(
          id: 'three',
          label: 'الثالث',
          icon: Icons.looks_3_rounded,
        ),
        DirectoryFilterOption(
          id: 'four',
          label: 'الخيار الرابع الطويل',
          icon: Icons.looks_4_rounded,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: const TextScaler.linear(1.35),
              ),
              child: child!,
            );
          },
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                DirectorySearchField(
                  controller: controller,
                  query: '',
                  onChanged: (_) {},
                  onClear: () {},
                  fieldKey: 'standalone-directory-search',
                  hintText: 'بحث تجريبي',
                ),
                DirectoryFilterBar(
                  options: options,
                  selectedId: 'one',
                  onSelected: (_) {},
                  barKey: 'standalone-directory-filters',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey<String>('standalone-directory-search'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('directory-filter-four')),
        findsOneWidget,
      );
      expectNoPhase06bException(tester);
    },
  );

  testWidgets(
    'صفحة البحث تتحمل شاشة ضيقة وخطًا مكبرًا ولوحة مفاتيح',
    (tester) async {
      await _verifyResponsivePage(
        tester,
        const DirectorySearchPage(),
      );
    },
  );

  testWidgets(
    'صفحة الأقسام تجعل تنبيه المصدر جزءًا من المحتوى القابل للتمرير',
    (tester) async {
      await _verifyResponsivePage(
        tester,
        const CategoriesOverviewPage(),
      );

      final scrollable = find.byKey(
        const PageStorageKey<String>(
          'categories-scrollable-services',
        ),
      );
      final statusBanner = find.byKey(
        const ValueKey<String>('categories-status-banner'),
      );

      expect(scrollable, findsOneWidget);
      expect(statusBanner, findsOneWidget);
      expect(
        find.descendant(
          of: scrollable,
          matching: statusBanner,
        ),
        findsOneWidget,
      );

      await tester.drag(scrollable, const Offset(0, -280));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>(
            'category-card-local-restaurants',
          ),
        ),
        findsOneWidget,
      );
      expectNoPhase06bException(tester);
    },
  );

  testWidgets(
    'صفحة جميع الأنشطة تتحمل شاشة ضيقة وخطًا مكبرًا ولوحة مفاتيح',
    (tester) async {
      await _verifyResponsivePage(
        tester,
        const AllBusinessesPage(),
      );
    },
  );

  testWidgets(
    'صفحة أنشطة القسم تتحمل شاشة ضيقة وخطًا مكبرًا ولوحة مفاتيح',
    (tester) async {
      await _verifyResponsivePage(
        tester,
        const CategoryListPage(
          categoryName: 'مطاعم',
          categoryId: 'local-restaurants',
          categoryIcon: Icons.restaurant_rounded,
        ),
      );
    },
  );
}

Future<void> _verifyResponsivePage(
  WidgetTester tester,
  Widget page,
) async {
  await pumpPhase06bPage(
    tester,
    page,
    size: const Size(320, 720),
    textScale: 1.35,
    keyboardInset: 300,
  );

  expectNoPhase06bException(tester);
}
