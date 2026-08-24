import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/business_app_link_service.dart';
import '../../core/services/push_notification_navigation_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../home/home_screen.dart';

typedef StartupUpdateCheck = Future<AppUpdateCheckResult?> Function();

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.updateCheckOverride,
  });

  final StartupUpdateCheck? updateCheckOverride;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _minimumSplashDuration = Duration(milliseconds: 1200);
  static const Duration _startupUpdateTimeout = Duration(seconds: 5);

  String _statusText = 'جارٍ التحقق من التحديثات وفتح قاعدة الدليل المحلية…';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final updateFuture = _checkForStartupUpdate();

    await Future.wait<void>([
      DirectoryDataStore.instance.load(),
      Future<void>.delayed(_minimumSplashDuration),
    ]);

    final updateResult = await updateFuture;

    if (!mounted) {
      return;
    }

    if (updateResult?.hasUpdate == true) {
      await _showStartupUpdateDialog(updateResult!);
      if (!mounted) {
        return;
      }
    }

    _openHome();
  }

  Future<AppUpdateCheckResult?> _checkForStartupUpdate() async {
    final override = widget.updateCheckOverride;
    if (override != null) {
      try {
        return await override().timeout(_startupUpdateTimeout);
      } catch (_) {
        // Tests and alternate launch flows use the same non-blocking contract.
        return null;
      } finally {
        if (mounted) {
          setState(() {
            _statusText = 'جارٍ فتح قاعدة الدليل المحلية…';
          });
        }
      }
    }

    final service = AppUpdateService();
    try {
      return await service.checkForUpdate().timeout(_startupUpdateTimeout);
    } catch (_) {
      // Update checks must never prevent the application from opening.
      return null;
    } finally {
      service.dispose();
      if (mounted) {
        setState(() {
          _statusText = 'جارٍ فتح قاعدة الدليل المحلية…';
        });
      }
    }
  }

  Future<void> _showStartupUpdateDialog(AppUpdateCheckResult result) async {
    final release = result.availableRelease;
    if (release == null || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          key: const ValueKey<String>('startup-update-dialog'),
          icon: const Icon(Icons.system_update_alt_rounded),
          title: Text(
            AppLocaleText.pick(
              context,
              ar: 'يتوفر تحديث جديد',
              en: 'A new update is available',
            ),
          ),
          content: Text(
            AppLocaleText.pick(
              context,
              ar: 'الإصدار المثبت: ${result.currentVersionLabel}\n'
                  'الإصدار الجديد: ${release.version.normalized}\n\n'
                  'يمكنك تنزيل التحديث الآن من مستودع دليل الحامي.',
              en: 'Installed version: ${result.currentVersionLabel}\n'
                  'New version: ${release.version.normalized}\n\n'
                  'You can download the update now from the Dalil Al Hami repository.',
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey<String>('startup-update-later'),
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                AppLocaleText.pick(
                  context,
                  ar: 'لاحقًا',
                  en: 'Later',
                ),
              ),
            ),
            FilledButton.icon(
              key: const ValueKey<String>('startup-update-download'),
              onPressed: () async {
                final launched = await launchUrl(
                  release.preferredDownloadUri,
                  mode: LaunchMode.externalApplication,
                );
                if (!dialogContext.mounted) {
                  return;
                }
                if (launched) {
                  Navigator.pop(dialogContext);
                  return;
                }

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocaleText.pick(
                        dialogContext,
                        ar: 'تعذر فتح رابط تنزيل التحديث.',
                        en: 'Could not open the update download link.',
                      ),
                    ),
                    backgroundColor: AppColors.danger,
                  ),
                );
              },
              icon: const Icon(Icons.download_rounded),
              label: Text(
                AppLocaleText.pick(
                  context,
                  ar: 'تنزيل التحديث',
                  en: 'Download update',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openHome() {
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
      BusinessAppLinkService.instance.markShellReady();
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
                  _statusText,
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
