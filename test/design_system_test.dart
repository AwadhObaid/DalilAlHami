import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/constants/app_catalog.dart';
import 'package:hami_guide/core/constants/app_colors.dart';
import 'package:hami_guide/core/constants/app_dimensions.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/home/widgets/category_circle_item.dart';

void main() {
  test('نظام التصميم يستخدم القيم المركزية المعتمدة', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, AppColors.primaryTeal);
    expect(theme.colorScheme.secondary, AppColors.lightTeal);
    expect(theme.scaffoldBackgroundColor, AppColors.pageBackground);
    expect(AppSpacing.md, 16);
    expect(AppRadius.md, 16);
    expect(AppSizes.minimumTouchTarget, 48);
  });

  testWidgets('عنصر القسم يناسب المساحة المخصصة دون تجاوز', (
    WidgetTester tester,
  ) async {
    final category = AppCatalog.transport.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 82,
              height: 106,
              child: CategoryCircleItem(
                category: category,
                onTap: _emptyCallback,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(category.name), findsOneWidget);
  });
}

void _emptyCallback() {}
