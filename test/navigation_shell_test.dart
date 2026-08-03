import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/constants/app_catalog.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/directory/categories_overview_page.dart';
import 'package:hami_guide/features/home/home_screen.dart';

void main() {
  testWidgets(
    'شريط التنقل يعمل ويحافظ على الصفحات على شاشة ضيقة',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const HomeScreen(),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('main-navigation-bar')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('nav-categories')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('تصفح خدمات مدينة الحامي حسب المجال'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('nav-search')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ما الذي تبحث عنه اليوم؟'), findsOneWidget);
    },
  );

  testWidgets(
    'الزر العائم يختفي عند ظهور لوحة المفاتيح ويعود بعد إغلاقها',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() {
        tester.view.resetViewInsets();
        tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const HomeScreen(initialIndex: 2),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('business-action-button')),
        findsOneWidget,
      );

      final searchField = find.byType(TextField).first;
      await tester.tap(searchField);
      await tester.pump();

      // showKeyboard وحدها لا تغيّر viewInsets في اختبار Widget.
      // نحاكي المساحة التي تحجبها لوحة المفاتيح كما يفعل النظام الحقيقي.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('business-action-button')),
        findsNothing,
      );

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('business-action-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'بطاقة القسم تتحمل أطول اسم مع تكبير النص دون تجاوز',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final longestCategory = AppCatalog.services.reduce(
        (current, next) =>
            current.name.length >= next.name.length ? current : next,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: const TextScaler.linear(1.25),
              ),
              child: child!,
            );
          },
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 104,
                height: 160,
                child: CategoryOverviewCard(
                  category: longestCategory,
                  businessCount: 0,
                  onTap: _emptyCallback,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(longestCategory.name), findsOneWidget);
      expect(find.text('لا توجد بيانات'), findsOneWidget);
    },
  );
}

void _emptyCallback() {}
