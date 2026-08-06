import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/service_category.dart';
import '../../shared/widgets/cached_directory_image.dart';

class CategoryCircleItem extends StatelessWidget {
  const CategoryCircleItem({
    required this.category,
    required this.onTap,
    this.accentIndex = 0,
    this.emphasized = false,
    super.key,
  });

  final ServiceCategory category;
  final VoidCallback onTap;
  final int accentIndex;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final visual = _CategoryVisual.forIndex(accentIndex);

    return Semantics(
      button: true,
      label: 'فتح قسم ${category.name}',
      child: SizedBox(
        width: 82,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxs,
                vertical: AppSpacing.xxs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: AppSizes.categoryIcon,
                    height: AppSizes.categoryIcon,
                    decoration: BoxDecoration(
                      color: emphasized ? AppColors.primaryTeal : visual.fill,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            emphasized ? AppColors.lightTeal : AppColors.white,
                        width: emphasized ? 2.5 : 2,
                      ),
                      boxShadow:
                          emphasized ? AppShadows.card : AppShadows.subtle,
                    ),
                    child: ClipOval(
                      child: (category.imageUrl?.trim().isNotEmpty ?? false)
                          ? CachedDirectoryImage(
                              source: category.imageUrl,
                              bucket: 'category-media',
                              width: AppSizes.categoryIcon,
                              height: AppSizes.categoryIcon,
                              fit: BoxFit.cover,
                              placeholder: _categoryIcon(visual),
                              errorWidget: _categoryIcon(visual),
                            )
                          : _categoryIcon(visual),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Flexible(
                    child: Center(
                      child: Text(
                        category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.15,
                          fontWeight:
                              emphasized ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: emphasized ? 30 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryIcon(_CategoryVisual visual) {
    return ColoredBox(
      color: emphasized ? AppColors.primaryTeal : visual.fill,
      child: Center(
        child: Icon(
          category.icon,
          color: emphasized ? AppColors.white : visual.foreground,
          size: 28,
        ),
      ),
    );
  }
}

class _CategoryVisual {
  const _CategoryVisual({
    required this.fill,
    required this.foreground,
  });

  final Color fill;
  final Color foreground;

  static _CategoryVisual forIndex(int index) {
    return switch (index % 6) {
      1 => const _CategoryVisual(
          fill: AppColors.categoryRoseSoft,
          foreground: Color(0xFFC34868),
        ),
      2 => const _CategoryVisual(
          fill: AppColors.categoryBlueSoft,
          foreground: Color(0xFF3979B8),
        ),
      3 => const _CategoryVisual(
          fill: AppColors.categoryLimeSoft,
          foreground: Color(0xFF43885A),
        ),
      4 => const _CategoryVisual(
          fill: AppColors.categoryPeachSoft,
          foreground: Color(0xFFB36B23),
        ),
      5 => const _CategoryVisual(
          fill: AppColors.categoryLavenderSoft,
          foreground: Color(0xFF6D55A8),
        ),
      _ => const _CategoryVisual(
          fill: AppColors.primarySoft,
          foreground: AppColors.primaryTeal,
        ),
    };
  }
}
