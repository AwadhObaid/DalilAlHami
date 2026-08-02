import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        fontFamily: 'Tajawal',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryTeal,
        ),
        useMaterial3: true,
      );
}
