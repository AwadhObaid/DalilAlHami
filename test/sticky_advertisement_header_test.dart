import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/data/directory_data_store.dart';
import 'package:hami_guide/features/home/home_screen.dart';
import 'package:hami_guide/features/home/widgets/sticky_advertisement_header.dart';

void main() {
  setUpAll(() {
    DirectoryDataStore.instance.prepareBundledDataForTesting();
  });

  testWidgets(
    'الإعلان يتحول إلى شريط مصغر ويبقى مثبتًا أثناء التمرير',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: SizedBox(height: 150),
                ),
                StickyAdvertisementHeader(
                  controller: controller,
                  advertisements: const [
                    'إعلان تجريبي لخدمات مدينة الحامي',
                    'مساحتك الإعلانية تصل إلى مستخدمي الدليل',
                  ],
                ),
                SliverList.builder(
                  itemCount: 30,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      height: 72,
                      child: Text('خدمة رقم $index'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('sticky-ad-expanded-content')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(
              find.byKey(
                const ValueKey<String>('sticky-advertisement-header'),
              ),
            )
            .height,
        greaterThanOrEqualTo(208),
      );
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -520),
      );
      await tester.pumpAndSettle();

      final headerFinder = find.byKey(
        const ValueKey<String>('sticky-advertisement-header'),
      );
      final headerRect = tester.getRect(headerFinder);

      expect(headerFinder, findsOneWidget);
      expect(headerRect.top, closeTo(0, 1.5));
      expect(headerRect.height, lessThan(110));
      expect(
        find.byKey(const ValueKey<String>('sticky-ad-compact-content')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'الإعلان المثبت يتحمل شاشة ضيقة وخطًا مكبرًا دون تجاوز',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            );
          },
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                StickyAdvertisementHeader(
                  controller: controller,
                  advertisements: const [
                    'إعلان طويل لخدمات وأنشطة مدينة الحامي التجارية',
                  ],
                ),
                SliverList.builder(
                  itemCount: 24,
                  itemBuilder: (context, index) {
                    return const SizedBox(height: 80);
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -420),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('sticky-advertisement-header')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'الإعلان المصغر يحترم الحافة الآمنة ولا يدخل خلف شريط حالة الهاتف',
    (WidgetTester tester) async {
      const statusBarInset = 30.0;

      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            const safePadding = EdgeInsets.only(top: statusBarInset);

            return MediaQuery(
              data: mediaQuery.copyWith(
                padding: safePadding,
                viewPadding: safePadding,
              ),
              child: child!,
            );
          },
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('home-safe-area-shell')),
        findsOneWidget,
      );

      final scrollView = find.byKey(
        const PageStorageKey<String>('home-dashboard-scroll'),
      );
      expect(scrollView, findsOneWidget);

      await tester.drag(scrollView, const Offset(0, -720));
      await tester.pumpAndSettle();

      final headerFinder = find.byKey(
        const ValueKey<String>('sticky-advertisement-header'),
      );
      final headerRect = tester.getRect(headerFinder);

      expect(headerFinder, findsOneWidget);
      expect(headerRect.top, closeTo(statusBarInset, 1.5));
      expect(headerRect.height, lessThan(110));
      expect(tester.takeException(), isNull);
    },
  );
}
