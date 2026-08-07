import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';

class SearchBox extends StatelessWidget {
  const SearchBox({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outline),
          boxShadow: AppShadows.card,
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onChanged,
          textAlign: TextAlign.start,
          textInputAction: TextInputAction.search,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: AppLocaleText.pick(
              context,
              ar: 'ابحث عن مطعم، صيدلية، ورشة أو اسم نشاط…',
              en: 'Search for a restaurant, pharmacy, workshop, or business…',
            ),
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primaryTeal,
              size: 27,
            ),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: AppLocaleText.pick(context,
                        ar: 'مسح البحث', en: 'Clear search'),
                    onPressed: onClear,
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 15,
            ),
          ),
        ),
      ),
    );
  }
}
