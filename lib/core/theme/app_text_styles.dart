import 'package:flutter/material.dart';

/// Typography tokens intentionally leave neutral text color to the surrounding
/// theme. This lets the same typography work correctly in light and dark mode.
abstract final class AppTextStyles {
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 26,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 19,
    height: 1.35,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 1.55,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 1.55,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );
}
