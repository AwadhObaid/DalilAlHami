import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/shared/widgets/directory_loading_skeleton.dart';

void main() {
  testWidgets(
    'قائمة التحميل الهيكلية لا تتجاوز الشاشة الضيقة',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: DirectoryLoadingSkeleton(),
          ),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(
          const ValueKey<String>('directory-loading-skeleton'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'شبكة تحميل الأقسام لا تتجاوز الشاشة الضيقة',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: CategoryLoadingSkeleton(),
          ),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(
          const ValueKey<String>('category-loading-skeleton'),
        ),
        findsOneWidget,
      );
    },
  );
}
