import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/constants/app_colors.dart';
import 'package:hami_guide/core/services/app_preferences_store.dart';

void main() {
  test('Phase 11B1 adaptive palette changes neutral surfaces by brightness',
      () {
    AppColors.configureForBrightness(Brightness.light);
    final lightSurface = AppColors.surface;
    final lightBackground = AppColors.pageBackground;
    final lightText = AppColors.textPrimary;

    AppColors.configureForBrightness(Brightness.dark);
    expect(AppColors.surface, isNot(lightSurface));
    expect(AppColors.pageBackground, isNot(lightBackground));
    expect(AppColors.textPrimary, isNot(lightText));
    expect(AppColors.isDark, isTrue);

    AppColors.configureForBrightness(Brightness.light);
    expect(AppColors.isDark, isFalse);
  });

  test('Phase 11B1 theme preference maps to Material ThemeMode', () {
    expect(AppThemeModePreset.system.materialThemeMode, ThemeMode.system);
    expect(AppThemeModePreset.light.materialThemeMode, ThemeMode.light);
    expect(AppThemeModePreset.dark.materialThemeMode, ThemeMode.dark);
  });

  test('Phase 11B1 source wiring is complete', () {
    final preferences = File(
      'lib/core/services/app_preferences_store.dart',
    ).readAsStringSync();
    final app = File('lib/app/hami_guide_app.dart').readAsStringSync();
    final theme = File('lib/core/theme/app_theme.dart').readAsStringSync();
    final settings = File(
      'lib/features/settings/app_settings_page.dart',
    ).readAsStringSync();
    final categoriesOverview = File(
      'lib/features/directory/categories_overview_page.dart',
    ).readAsStringSync();

    for (final token in <String>[
      'AppThemeModePreset',
      'phase11b_theme_mode_v1',
      'setThemeModePreset',
    ]) {
      expect(preferences, contains(token), reason: token);
    }

    final themeSnapshotUpdate = preferences.indexOf(
      '_snapshot = _snapshot.copyWith(themeModePreset: preset);',
    );
    final themePersistence = preferences.indexOf(
      'await _preferences!.setString(themeModeKey, preset.storageValue);',
    );
    expect(themeSnapshotUpdate, greaterThanOrEqualTo(0));
    expect(themePersistence, greaterThan(themeSnapshotUpdate));

    for (final token in <String>[
      'darkTheme: AppTheme.dark',
      'themeMode: snapshot.themeModePreset.materialThemeMode',
      'AppColors.configureForBrightness',
      'themeAnimationDuration: Duration.zero',
      'platformDispatcher.platformBrightness',
    ]) {
      expect(app, contains(token), reason: token);
    }

    for (final token in <String>[
      'static ThemeData get dark',
      'Brightness.dark',
      'ColorScheme.dark',
    ]) {
      expect(theme, contains(token), reason: token);
    }

    for (final token in <String>[
      'settings-theme-system',
      'settings-theme-light',
      'settings-theme-dark',
    ]) {
      expect(settings, contains(token), reason: token);
    }

    expect(
      categoriesOverview,
      contains('static List<Color> get _accentBackgrounds'),
      reason: 'adaptive category colors must be evaluated at runtime',
    );
    expect(
      categoriesOverview,
      isNot(contains('static const List<Color> _accentBackgrounds')),
      reason: 'adaptive AppColors getters cannot be stored in a const list',
    );
  });
}
