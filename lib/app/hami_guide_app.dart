import 'package:flutter/material.dart';

import '../core/navigation/app_navigator.dart';
import '../core/theme/app_theme.dart';
import '../features/splash/splash_screen.dart';

class HamiGuideApp extends StatelessWidget {
  const HamiGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'دليل الحامي',
      theme: AppTheme.light,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SplashScreen(),
    );
  }
}
