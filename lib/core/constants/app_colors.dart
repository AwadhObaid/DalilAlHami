import 'package:flutter/material.dart';

/// لوحة الألوان المركزية لتطبيق دليل الحامي.
///
/// لا تُستخدم قيم ألوان مباشرة داخل الواجهات الجديدة؛ بل تُضاف هنا أولًا
/// للحفاظ على اتساق الهوية البصرية وسهولة تطوير الوضع الداكن لاحقًا.
abstract final class AppColors {
  static const Color primaryTeal = Color(0xFF006577);
  static const Color primaryDark = Color(0xFF004D5B);
  static const Color primarySoft = Color(0xFFDDF1F2);

  static const Color lightTeal = Color(0xFF2CC9A6);
  static const Color mintSoft = Color(0xFFDFF8F1);

  static const Color background = Color(0xFFF0F7F7);
  static const Color pageBackground = Color(0xFFF7FAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEDF4F5);

  static const Color textPrimary = Color(0xFF173A41);
  static const Color textSecondary = Color(0xFF61777C);
  static const Color textMuted = Color(0xFF879A9E);

  static const Color outline = Color(0xFFD6E5E7);
  static const Color outlineStrong = Color(0xFFB7CDD0);

  static const Color success = Color(0xFF168A63);
  static const Color whatsapp = Color(0xFF1FAF68);
  static const Color warning = Color(0xFFE99A2E);
  static const Color danger = Color(0xFFC94B4B);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}
