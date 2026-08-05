import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/constants/app_catalog.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/data/directory_data_store.dart';
import 'package:hami_guide/features/directory/categories_overview_page.dart';
import 'package:hami_guide/features/home/home_screen.dart';

void main() {
  setUp(() {
    DirectoryDataStore.instance.prepareBundledDataForTesting();
  });

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
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(
          const ValueKey<String>('my-activities-sign-in-prompt'),
        ),
        findsOneWidget,
      );
      expect(find.text('سجّل الدخول لإدارة أنشطتك'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('nav-search')),
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('search-prompt')),
        findsOneWidget,
      );
      expect(find.text('ما الذي تبحث عنه اليوم؟'), findsOneWidget);
    },
  );

  testWidgets(
    'الزر العائم يختفي عند ظهور لوحة المفاتيح ويعود بعد إغلاقها',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final keyboardInset = ValueNotifier<double>(0);
      addTearDown(keyboardInset.dispose);

      await tester.pumpWidget(
        _KeyboardInsetHarness(
          keyboardInset: keyboardInset,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('search-prompt')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('business-action-button')),
        findsOneWidget,
      );

      keyboardInset.value = 300;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('business-action-button')),
        findsNothing,
      );

      keyboardInset.value = 0;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

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

class _KeyboardInsetHarness extends StatelessWidget {
  const _KeyboardInsetHarness({
    required this.keyboardInset,
  });

  final ValueListenable<double> keyboardInset;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: keyboardInset,
      builder: (context, inset, child) {
        return MaterialApp(
          theme: AppTheme.light,
          builder: (context, appChild) {
            final mediaQuery = MediaQuery.of(context);

            return MediaQuery(
              data: mediaQuery.copyWith(
                viewInsets: EdgeInsets.only(bottom: inset),
              ),
              child: appChild!,
            );
          },
          home: const HomeScreen(initialIndex: 2),
        );
      },
    );
  }
}

void _emptyCallback() {}
