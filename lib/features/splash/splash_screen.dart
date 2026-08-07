import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/push_notification_navigation_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait<void>([
      DirectoryDataStore.instance.load(),
      Future<void>.delayed(const Duration(milliseconds: 1200)),
    ]);

    if (!mounted) {
      return;
    }

    unawaited(
      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) => const HomeScreen(),
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationNavigationService.instance.markShellReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Scaffold(
      backgroundColor: AppColors.primaryTeal,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 120,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.location_city_rounded,
                      size: 80,
                      color: AppColors.white,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'أهلاً بك في التطبيق',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: Colors.yellow,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'دليلك السريع للوصول إلى الأرقام بكل سهولة',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: AppColors.lightTeal,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'جارٍ فتح قاعدة الدليل المحلية…',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
