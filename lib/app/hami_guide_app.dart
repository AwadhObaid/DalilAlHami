import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigator.dart';
import '../core/services/app_preferences_store.dart';
import '../core/theme/app_theme.dart';
import '../features/splash/splash_screen.dart';

class HamiGuideApp extends StatelessWidget {
  const HamiGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    final preferences = AppPreferencesStore.instance;

    return AnimatedBuilder(
      animation: preferences,
      builder: (context, _) {
        final snapshot = preferences.snapshot;
        final effectiveBrightness = switch (snapshot.themeModePreset) {
          AppThemeModePreset.light => Brightness.light,
          AppThemeModePreset.dark => Brightness.dark,
          AppThemeModePreset.system =>
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
        };

        // Keep legacy adaptive AppColors in sync before descendants rebuild.
        // Phase 11B1 uses an instant theme switch because these tokens are
        // discrete rather than interpolated ColorScheme values.
        AppColors.configureForBrightness(effectiveBrightness);

        return MaterialApp(
          navigatorKey: appNavigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'دليل الحامي',
          locale: Locale(snapshot.localeCode),
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: snapshot.themeModePreset.materialThemeMode,
          themeAnimationDuration: Duration.zero,
          themeAnimationCurve: Curves.linear,
          builder: (context, child) {
            final brightness = Theme.of(context).brightness;
            AppColors.configureForBrightness(brightness);

            final mediaQuery = MediaQuery.of(context);
            final systemScale = mediaQuery.textScaler.scale(1);
            final requestedScale = systemScale * snapshot.textScaleFactor;
            final safeScale = requestedScale.clamp(0.9, 1.35).toDouble();

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(safeScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
