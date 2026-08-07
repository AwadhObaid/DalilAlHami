import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';

class DirectoryPageHeader extends StatelessWidget {
  const DirectoryPageHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.action,
    this.onBack,
    this.bottom,
    this.headerKey,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;
  final VoidCallback? onBack;
  final Widget? bottom;
  final String? headerKey;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: headerKey == null ? null : ValueKey<String>(headerKey!),
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppColors.primaryDark,
              AppColors.primaryTeal,
              AppColors.lightTeal,
            ],
            stops: [0, 0.66, 1],
          ),
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (onBack != null) ...[
                      _HeaderActionButton(
                        tooltip: 'رجوع',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: onBack!,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.white.withValues(alpha: 0.84),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      action!,
                    ],
                  ],
                ),
                if (bottom != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  bottom!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DirectoryHeaderRefreshButton extends StatelessWidget {
  const DirectoryHeaderRefreshButton({
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return _HeaderActionButton(
      tooltip: isLoading ? 'جارٍ التحديث' : 'تحديث البيانات',
      icon: Icons.refresh_rounded,
      onPressed: isLoading ? null : onPressed,
      showProgress: isLoading,
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.showProgress = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.white.withValues(alpha: 0.13),
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.white.withValues(alpha: 0.08),
        disabledForegroundColor: AppColors.white.withValues(alpha: 0.7),
        minimumSize: const Size(42, 42),
        maximumSize: const Size(42, 42),
        padding: EdgeInsets.zero,
      ),
      icon: showProgress
          ? const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.white,
              ),
            )
          : Icon(icon, size: 23),
    );
  }
}
