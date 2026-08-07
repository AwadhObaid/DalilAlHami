import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/constants/app_colors.dart';

class _ThemeProbe extends StatelessWidget {
  const _ThemeProbe();

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return ColoredBox(
      key: const ValueKey<String>('phase11b1-theme-probe'),
      color: AppColors.surface,
      child: const SizedBox(width: 24, height: 24),
    );
  }
}

void main() {
  testWidgets('legacy AppColors widgets rebuild immediately with Theme', (
    tester,
  ) async {
    final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
    addTearDown(themeMode.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (context, mode, _) {
          return MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: mode,
            themeAnimationDuration: Duration.zero,
            home: const Scaffold(body: _ThemeProbe()),
          );
        },
      ),
    );

    final lightColor = tester
        .widget<ColoredBox>(
          find.byKey(const ValueKey<String>('phase11b1-theme-probe')),
        )
        .color;

    themeMode.value = ThemeMode.dark;
    await tester.pump();

    final darkColor = tester
        .widget<ColoredBox>(
          find.byKey(const ValueKey<String>('phase11b1-theme-probe')),
        )
        .color;

    expect(lightColor, isNot(darkColor));
    expect(AppColors.isDark, isTrue);
  });

  test('every legacy AppColors widget build binds to Material Theme', () {
    final lib = Directory('lib');
    final violations = <String>[];
    final buildPattern =
        RegExp(r'Widget\s+build\(BuildContext\s+context\)\s*\{');
    const bindToken = 'AppColors.bindToTheme(context);';
    const excluded = <String>{
      'lib/app/hami_guide_app.dart',
      'lib/core/constants/app_colors.dart',
      'lib/core/theme/app_theme.dart',
    };

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final path = entity.path.replaceAll('\\', '/');
      if (excluded.contains(path)) {
        continue;
      }

      final source = entity.readAsStringSync();
      if (!source.contains('AppColors.')) {
        continue;
      }

      final buildCount = buildPattern.allMatches(source).length;
      if (buildCount == 0) {
        continue;
      }
      final bindCount = bindToken.allMatches(source).length;
      if (bindCount < buildCount) {
        violations.add('$path: build=$buildCount bind=$bindCount');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Widgets that read legacy AppColors must depend on Theme.of(context) '
          'so Light/Dark changes repaint in the same frame.\n'
          '${violations.join('\n')}',
    );
  });
  test('theme-sensitive legacy surfaces do not use implicit color animation',
      () {
    final home = File('lib/features/home/home_screen.dart').readAsStringSync();
    final syncBanner = File(
      'lib/features/home/widgets/automatic_sync_status_banner.dart',
    ).readAsStringSync();
    final advertisement = File(
      'lib/features/shared/widgets/inline_advertisement_banner.dart',
    ).readAsStringSync();
    final category = File(
      'lib/features/home/widgets/category_circle_item.dart',
    ).readAsStringSync();

    expect(home, isNot(contains('AnimatedContainer(')));
    expect(syncBanner, isNot(contains('AnimatedContainer(')));
    expect(advertisement, isNot(contains('AnimatedContainer(')));
    expect(
      'AnimatedContainer('.allMatches(category).length,
      1,
      reason: 'Only the category emphasis underline may animate; its color is '
          'theme-invariant.',
    );
    expect(syncBanner, contains('background: AppColors.warningSoft'));
    expect(syncBanner, contains('background: AppColors.dangerSoft'));
  });
}
