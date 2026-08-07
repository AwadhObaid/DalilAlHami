import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';

class AdminDashboardEntryCard extends StatelessWidget {
  const AdminDashboardEntryCard({
    super.key,
    required this.onTap,
  });

  static const ValueKey<String> cardKey =
      ValueKey<String>('account-admin-dashboard-entry');

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Material(
      key: cardKey,
      color: AppColors.primaryDeep,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppColors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لوحة تحكم الإدارة',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'متابعة المستخدمين والأنشطة والأقسام والإعلانات',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
