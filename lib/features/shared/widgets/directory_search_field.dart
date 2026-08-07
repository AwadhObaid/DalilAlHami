import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';

class DirectorySearchField extends StatelessWidget {
  const DirectorySearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    required this.fieldKey,
    required this.hintText,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String fieldKey;
  final String hintText;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final radius = BorderRadius.circular(AppRadius.lg);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: TextField(
          key: ValueKey<String>(fieldKey),
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: onChanged,
          textAlign: TextAlign.start,
          textInputAction: TextInputAction.search,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primaryTeal,
              size: 25,
            ),
            suffixIcon: query.trim().isEmpty
                ? null
                : IconButton(
                    key: ValueKey<String>('$fieldKey-clear'),
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
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}
