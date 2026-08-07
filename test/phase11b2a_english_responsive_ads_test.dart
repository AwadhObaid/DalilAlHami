import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/app_preferences_store.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/home/widgets/sticky_advertisement_header.dart';
import 'package:hami_guide/features/shared/widgets/inline_advertisement_banner.dart';
import 'package:hami_guide/models/directory_advertisement.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppPreferencesStore.instance.initialize(reload: true);
  });

  setUp(() async {
    await AppPreferencesStore.instance.setLocaleCode('en');
  });

  testWidgets(
    'English inline advertisement fits a narrow screen with enlarged text',
    (tester) async {
      const advertisement = DirectoryAdvertisement(
        id: 'phase11b2a-inline-en',
        title: 'عرض خاص لزوار دليل الحامي',
        sortOrder: 1,
        placement: 'home_middle',
        targetUrl: 'https://example.com/offer',
      );

      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
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
          home: const Scaffold(
            body: InlineAdvertisementBanner(
              advertisements: <DirectoryAdvertisement>[advertisement],
              onOpen: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('inline-advertisement-banner')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'English compact sticky advertisement fits narrow enlarged text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
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
              slivers: <Widget>[
                StickyAdvertisementHeader(
                  controller: controller,
                  advertisements: const <String>[
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

      expect(
        find.byKey(const ValueKey<String>('sticky-advertisement-header')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
