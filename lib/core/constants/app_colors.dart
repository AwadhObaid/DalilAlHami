import 'package:flutter/material.dart';

/// Semantic application palette.
///
/// Phase 11B1 keeps the existing public color API while allowing the neutral
/// and soft-surface colors to follow the active Material brightness. Accent
/// colors stay stable so the Hami Guide identity remains recognizable in both
/// light and dark modes.
abstract final class AppColors {
  static Brightness _brightness = Brightness.light;

  static void configureForBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  /// Registers this widget as a dependent of the active Material theme.
  ///
  /// AppColors keeps a compatibility palette for legacy screens. Widgets that
  /// read these static tokens must still depend on Theme so Flutter rebuilds
  /// them immediately when Light/Dark/System changes.
  static void bindToTheme(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (_brightness != brightness) {
      _brightness = brightness;
    }
  }

  static bool get isDark => _brightness == Brightness.dark;

  static const Color primaryTeal = Color(0xFF008F84);
  static const Color primaryDark = Color(0xFF00646D);
  static const Color primaryDeep = Color(0xFF064D57);
  static Color get primarySoft =>
      isDark ? const Color(0xFF123B3B) : const Color(0xFFE2F5F3);

  static const Color lightTeal = Color(0xFF27C8AD);
  static const Color mint = Color(0xFF71DCCB);
  static Color get mintSoft =>
      isDark ? const Color(0xFF143A34) : const Color(0xFFE8F8F4);

  static Color get background =>
      isDark ? const Color(0xFF0C171A) : const Color(0xFFF1F7F7);
  static Color get pageBackground =>
      isDark ? const Color(0xFF0B1518) : const Color(0xFFF8FAFA);
  static Color get surface =>
      isDark ? const Color(0xFF122226) : const Color(0xFFFFFFFF);
  static Color get surfaceMuted =>
      isDark ? const Color(0xFF192D31) : const Color(0xFFF0F5F5);
  static Color get surfaceTint =>
      isDark ? const Color(0xFF10282A) : const Color(0xFFF4FBFA);

  static Color get textPrimary =>
      isDark ? const Color(0xFFE7F5F3) : const Color(0xFF17383F);
  static Color get textSecondary =>
      isDark ? const Color(0xFFB5CCCA) : const Color(0xFF60767B);
  static Color get textMuted =>
      isDark ? const Color(0xFF829B9A) : const Color(0xFF91A2A5);

  static Color get outline =>
      isDark ? const Color(0xFF284146) : const Color(0xFFDCE8E9);
  static Color get outlineStrong =>
      isDark ? const Color(0xFF3A5B60) : const Color(0xFFBED2D4);

  static const Color success = Color(0xFF14946C);
  static const Color whatsapp = Color(0xFF1FAF68);
  static const Color warning = Color(0xFFE89B2D);
  static Color get warningSoft =>
      isDark ? const Color(0xFF3A2A10) : const Color(0xFFFFF4E3);
  static const Color danger = Color(0xFFC94B4B);
  static Color get dangerSoft =>
      isDark ? const Color(0xFF3A1B1B) : const Color(0xFFFFECEC);

  static const Color advertisementGold = Color(0xFFF8B52E);
  static Color get advertisementGoldSoft =>
      isDark ? const Color(0xFF403012) : const Color(0xFFFFF1C9);
  static Color get advertisementInk =>
      isDark ? const Color(0xFFE9F9F7) : const Color(0xFF073F44);

  static Color get categoryBlueSoft =>
      isDark ? const Color(0xFF172D3A) : const Color(0xFFE7F2FF);
  static Color get categoryRoseSoft =>
      isDark ? const Color(0xFF3A2029) : const Color(0xFFFFEAF0);
  static Color get categoryLavenderSoft =>
      isDark ? const Color(0xFF2B2540) : const Color(0xFFF0EAFF);
  static Color get categoryPeachSoft =>
      isDark ? const Color(0xFF3A2A1F) : const Color(0xFFFFF0E3);
  static Color get categoryLimeSoft =>
      isDark ? const Color(0xFF253624) : const Color(0xFFECF8E6);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}
