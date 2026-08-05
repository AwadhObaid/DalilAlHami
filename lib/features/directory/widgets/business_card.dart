import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/launch_actions.dart';
import '../../../models/business.dart';
import 'business_image.dart';

class BusinessCard extends StatelessWidget {
  const BusinessCard({
    required this.business,
    required this.onOpen,
    super.key,
  });

  final Business business;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'فتح تفاصيل ${business.displayName}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outline),
          boxShadow: AppShadows.subtle,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                key: ValueKey<String>(
                  'business-card-layout-${business.id}',
                ),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BusinessImage(
                        business: business,
                        width: 82,
                        height: 82,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        heroEnabled: true,
                        iconSize: 36,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _BusinessSummary(business: business),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.xxs),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 17,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (business.displayDetails.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      business.displayDetails,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _ContactButton(
                          label: 'اتصال',
                          icon: Icons.phone_rounded,
                          color: AppColors.primaryTeal,
                          enabled: business.hasPhone,
                          onPressed: () {
                            LaunchActions.makePhoneCall(
                              context,
                              business.phone,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _ContactButton(
                          label: 'واتساب',
                          icon: Icons.chat_bubble_rounded,
                          color: AppColors.whatsapp,
                          enabled: business.hasWhatsApp,
                          onPressed: () {
                            LaunchActions.openWhatsApp(
                              context,
                              business.whatsappContact,
                              message: 'مرحبًا، تواصلت معكم عبر دليل الحامي '
                                  'بخصوص ${business.displayName}.',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessSummary extends StatelessWidget {
  const _BusinessSummary({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                business.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleMedium,
              ),
            ),
            if (business.isFeatured) ...[
              const SizedBox(width: AppSpacing.xxs),
              const Tooltip(
                message: 'نشاط مميز',
                child: Icon(
                  Icons.verified_rounded,
                  size: 19,
                  color: AppColors.lightTeal,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xxs,
          children: [
            _InfoChip(
              icon: Icons.category_outlined,
              text: business.displayCategory,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 17,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: Text(
                business.displayPlace,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: AppColors.primaryTeal,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppSizes.minimumTouchTarget,
      ),
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor:
              enabled ? color.withValues(alpha: 0.07) : AppColors.surfaceMuted,
          side: BorderSide(
            color: enabled ? color.withValues(alpha: 0.3) : AppColors.outline,
          ),
          minimumSize: const Size.fromHeight(
            AppSizes.minimumTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          textStyle: AppTextStyles.labelMedium,
        ),
        icon: Icon(icon, size: 19),
        label: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
