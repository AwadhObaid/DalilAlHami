import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/data/directory_data_store.dart';
import 'package:hami_guide/features/home/home_screen.dart';

void preparePhase06aDirectoryData() {
  DirectoryDataStore.instance.prepareBundledDataForTesting();
}

Future<void> pumpPhase06aHome(
  WidgetTester tester, {
  Size size = const Size(360, 800),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: const HomeScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> dragHomeUntilBuilt(
  WidgetTester tester,
  Finder target, {
  double distance = 280,
  int maxDrags = 16,
}) async {
  const scrollKey = PageStorageKey<String>('home-dashboard-scroll');
  final scrollView = find.byKey(scrollKey);

  expect(
    scrollView,
    findsOneWidget,
    reason: 'تعذر العثور على تمرير الصفحة الرئيسية.',
  );

  for (var attempt = 0; attempt < maxDrags; attempt += 1) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pump();
      return;
    }

    await tester.drag(
      scrollView,
      Offset(0, -distance),
    );
    await tester.pump(const Duration(milliseconds: 120));
  }

  expect(
    target,
    findsOneWidget,
    reason: 'لم يُبنَ العنصر بعد $maxDrags محاولات تمرير.',
  );

  await tester.ensureVisible(target);
  await tester.pump();
}
