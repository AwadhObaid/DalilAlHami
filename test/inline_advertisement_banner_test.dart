import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/shared/widgets/inline_advertisement_banner.dart';
import 'package:hami_guide/models/directory_advertisement.dart';

void main() {
  testWidgets('يعرض الإعلان الداخلي بأمان على شاشة ضيقة وخط مكبر ويفتح وجهته',
      (tester) async {
    DirectoryAdvertisement? opened;
    const advertisement = DirectoryAdvertisement(
      id: 'ad-inline',
      title: 'عرض خاص لزوار دليل الحامي',
      sortOrder: 1,
      placement: 'home_middle',
      targetUrl: 'https://example.com/offer',
    );

    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
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
          body: InlineAdvertisementBanner(
            advertisements: const [advertisement],
            onOpen: (value) => opened = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('inline-advertisement-banner')),
      findsOneWidget,
    );
    expect(find.text('عرض خاص لزوار دليل الحامي'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('inline-advertisement-ad-inline'),
      ),
    );
    await tester.pump();

    expect(opened?.id, 'ad-inline');
    expect(tester.takeException(), isNull);
  });
}
