import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/data/directory_data_store.dart';
import 'package:hami_guide/features/directory/all_businesses_page.dart';

void main() {
  setUpAll(() {
    DirectoryDataStore.instance.prepareBundledDataForTesting();
  });

  testWidgets(
    'صفحة جميع الأنشطة تُبنى من بيانات الدليل الفعلية',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const AllBusinessesPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AllBusinessesPage), findsOneWidget);
      expect(find.text('جميع الأنشطة'), findsOneWidget);
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
