import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/directory_data_store.dart';
import 'package:hami_guide/features/home/home_screen.dart';
import 'package:hami_guide/main.dart';

void main() {
  setUpAll(() {
    DirectoryDataStore.instance.prepareBundledDataForTesting();
  });

  testWidgets(
    'يفتح التطبيق وينتقل من شاشة البداية إلى حاوية التنقل',
    (WidgetTester tester) async {
      await tester.pumpWidget(const HamiGuideApp());

      expect(find.text('أهلاً بك في التطبيق'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('main-navigation-bar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('nav-home')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('nav-categories')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('nav-search')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('nav-account')),
        findsOneWidget,
      );
      expect(
        find.text('ابحث عن مطعم، صيدلية، ورشة أو اسم نشاط…'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
