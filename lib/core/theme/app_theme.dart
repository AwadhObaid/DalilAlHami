import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static const Color _darkBackground = Color(0xFF0B1518);
  static const Color _darkSurface = Color(0xFF122226);
  static const Color _darkTextPrimary = Color(0xFFE7F5F3);
  static const Color _darkTextSecondary = Color(0xFFB5CCCA);
  static const Color _darkOutline = Color(0xFF284146);
  static const Color _darkOutlineStrong = Color(0xFF3A5B60);
  static const Color _darkPrimaryContainer = Color(0xFF123B3B);
  static const Color _darkSecondaryContainer = Color(0xFF143A34);

  static ThemeData get light => _buildTheme(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primaryTeal,
          onPrimary: AppColors.white,
          primaryContainer: Color(0xFFE2F5F3),
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.lightTeal,
          onSecondary: AppColors.primaryDark,
          secondaryContainer: Color(0xFFE8F8F4),
          onSecondaryContainer: AppColors.primaryDark,
          surface: AppColors.white,
          onSurface: Color(0xFF17383F),
          onSurfaceVariant: Color(0xFF60767B),
          error: AppColors.danger,
          onError: AppColors.white,
          outline: Color(0xFFBED2D4),
          outlineVariant: Color(0xFFDCE8E9),
        ),
        scaffoldBackground: const Color(0xFFF8FAFA),
        appBarBackground: AppColors.primaryTeal,
        appBarForeground: AppColors.white,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      );

  static ThemeData get dark => _buildTheme(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.lightTeal,
          onPrimary: Color(0xFF052C2C),
          primaryContainer: _darkPrimaryContainer,
          onPrimaryContainer: Color(0xFFD7FFFA),
          secondary: AppColors.mint,
          onSecondary: Color(0xFF082D28),
          secondaryContainer: _darkSecondaryContainer,
          onSecondaryContainer: Color(0xFFD9FFF5),
          surface: _darkSurface,
          onSurface: _darkTextPrimary,
          onSurfaceVariant: _darkTextSecondary,
          error: Color(0xFFFF8F8F),
          onError: Color(0xFF3B0808),
          outline: _darkOutlineStrong,
          outlineVariant: _darkOutline,
        ),
        scaffoldBackground: _darkBackground,
        appBarBackground: const Color(0xFF083F47),
        appBarForeground: _darkTextPrimary,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color appBarBackground,
    required Color appBarForeground,
    required Brightness statusBarBrightness,
    required Brightness statusBarIconBrightness,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Tajawal',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      canvasColor: colorScheme.surface,
      cardColor: colorScheme.surface,
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      splashColor: colorScheme.primary.withValues(alpha: 0.12),
      highlightColor: colorScheme.primary.withValues(alpha: 0.06),
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.headlineLarge.copyWith(
          color: colorScheme.onSurface,
        ),
        headlineMedium: AppTextStyles.headlineMedium.copyWith(
          color: colorScheme.onSurface,
        ),
        titleLarge: AppTextStyles.titleLarge.copyWith(
          color: colorScheme.onSurface,
        ),
        titleMedium: AppTextStyles.titleMedium.copyWith(
          color: colorScheme.onSurface,
        ),
        titleSmall: AppTextStyles.titleSmall.copyWith(
          color: colorScheme.onSurface,
        ),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(
          color: colorScheme.onSurface,
        ),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(
          color: colorScheme.onSurface,
        ),
        bodySmall: AppTextStyles.bodySmall.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelLarge: AppTextStyles.labelLarge.copyWith(
          color: colorScheme.onSurface,
        ),
        labelMedium: AppTextStyles.labelMedium.copyWith(
          color: colorScheme.onSurface,
        ),
        labelSmall: AppTextStyles.labelSmall.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: appBarBackground,
          statusBarIconBrightness: statusBarIconBrightness,
          statusBarBrightness: statusBarBrightness,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 19,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: appBarForeground,
        ),
        iconTheme: IconThemeData(
          color: appBarForeground,
          size: 24,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 15,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        prefixIconColor: colorScheme.primary,
        suffixIconColor: colorScheme.primary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minimumTouchTarget),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          textStyle: AppTextStyles.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minimumTouchTarget),
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          textStyle: AppTextStyles.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(
            AppSizes.minimumTouchTarget,
            AppSizes.minimumTouchTarget,
          ),
          textStyle: AppTextStyles.labelMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color:
                  selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              size: selected ? 25 : 23,
            );
          },
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (states) {
            final selected = states.contains(WidgetState.selected);
            return AppTextStyles.labelSmall.copyWith(
              color:
                  selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            );
          },
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 8,
        focusElevation: 8,
        hoverElevation: 10,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? const Color(0xFF20363A) : const Color(0xFF17383F),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.white,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: AppSpacing.md,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.28),
        selectionHandleColor: colorScheme.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: AppTextStyles.labelMedium.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
