import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/home/widgets/ad_slider.dart';
import 'package:hami_guide/features/home/widgets/sticky_advertisement_header.dart';

void main() {
  testWidgets(
    'عقد الإعلان يختبر التركيب والسلوك الفعلي بدل نصوص الملفات',
    (tester) async {
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
                StickyAdvertisementHeader(
                  controller: controller,
                  advertisements: const [
                    'إعلان محلي تجريبي',
                  ],
                ),
                SliverList.builder(
                  itemCount: 30,
                  itemBuilder: (context, index) => const SizedBox(height: 90),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(StickyAdvertisementHeader), findsOneWidget);
      expect(find.byType(AdSlider), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('sticky-advertisement-header'),
        ),
        findsOneWidget,
      );

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -620),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('sticky-ad-compact-content'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
