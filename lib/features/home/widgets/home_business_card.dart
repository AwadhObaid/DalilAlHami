import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/launch_actions.dart';
import '../../../models/business.dart';
import '../../directory/widgets/business_favorite_button.dart';
import '../../directory/widgets/business_image.dart';

class HomeBusinessCard extends StatelessWidget {
  const HomeBusinessCard({
    required this.business,
    required this.onOpen,
    super.key,
  });

  final Business business;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      key: ValueKey<String>('home-business-card-${business.id}'),
      decoration: BoxDecoration(
        color: business.isFeatured ? AppColors.surfaceTint : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: business.isFeatured
              ? AppColors.lightTeal.withValues(alpha: 0.28)
              : AppColors.outline,
        ),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 112,
                    child: _BusinessContent(
                      business: business,
                      onOpen: onOpen,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                BusinessImage(
                  business: business,
                  width: AppSizes.homeBusinessImageWidth,
                  height: 112,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  heroEnabled: true,
                  iconSize: 40,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessContent extends StatelessWidget {
  const _BusinessContent({
    required this.business,
    required this.onOpen,
  });

  final Business business;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                business.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleMedium,
              ),
            ),
            if (business.isFeatured)
              Container(
                margin: const EdgeInsetsDirectional.only(start: 5),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'مميز',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            const Icon(
              Icons.category_outlined,
              size: 16,
              color: AppColors.primaryTeal,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: Text(
                business.displayCategory,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: Text(
                business.displayPlace,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: business.hasPhone
                    ? () {
                        LaunchActions.makePhoneCall(
                          context,
                          business.phone,
                        );
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  foregroundColor: AppColors.primaryTeal,
                  backgroundColor: AppColors.primarySoft,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.phone_rounded, size: 17),
                label: const Text('اتصال'),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            BusinessFavoriteButton(
              businessId: business.id,
              outlined: true,
              size: 20,
            ),
          ],
        ),
      ],
    );
  }
}
