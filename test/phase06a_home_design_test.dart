import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/constants/app_catalog.dart';
import 'package:hami_guide/core/constants/app_dimensions.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/home/widgets/category_circle_item.dart';
import 'package:hami_guide/features/home/widgets/home_header.dart';
import 'package:hami_guide/features/home/widgets/home_sync_strip.dart';

import 'phase06a_test_harness.dart';

void main() {
  setUpAll(preparePhase06aDirectoryData);

  testWidgets(
    'الهيدر المختصر يعرض الهوية والبحث والفلاتر دون تجاوز',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HomeHeader(
              onOpenSearch: _emptyCallback,
              onOpenFilters: _emptyCallback,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('دليل الحامي'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('home-search-launcher')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('home-filter-button')),
        findsOneWidget,
      );

      final headerSize = tester.getSize(
        find.byKey(const ValueKey<String>('home-hero-header')),
      );
      expect(AppSizes.homeHeaderHeight, lessThanOrEqualTo(230));
      expect(headerSize.height, lessThanOrEqualTo(230));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'الفئة المميزة تستخدم مكون الأيقونة الدائرية',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 88,
                height: 132,
                child: CategoryCircleItem(
                  category: AppCatalog.transport.first,
                  emphasized: true,
                  onTap: _emptyCallback,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(AppCatalog.transport.first.name),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'بطاقة المزامنة الكبيرة غير موجودة في الصفحة الرئيسية',
    (tester) async {
      await pumpPhase06aHome(tester);

      expect(find.byType(HomeSyncStrip), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

void _emptyCallback() {}
