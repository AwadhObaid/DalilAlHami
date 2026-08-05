import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';

class DirectoryFilterOption {
  const DirectoryFilterOption({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

class DirectoryFilterBar extends StatelessWidget {
  const DirectoryFilterBar({
    required this.options,
    required this.selectedId,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    this.barKey,
    super.key,
  });

  final List<DirectoryFilterOption> options;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry padding;
  final String? barKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        key: barKey == null ? null : ValueKey<String>(barKey!),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: SingleChildScrollView(
          key: ValueKey<String>(
            '${barKey ?? 'directory-filter-bar'}-scroll',
          ),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < options.length; index++) ...[
                  if (index > 0) const SizedBox(width: AppSpacing.xs),
                  _DirectoryFilterChip(
                    option: options[index],
                    selected: options[index].id == selectedId,
                    onSelected: onSelected,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryFilterChip extends StatelessWidget {
  const _DirectoryFilterChip({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  final DirectoryFilterOption option;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      key: ValueKey<String>('directory-filter-${option.id}'),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(option.id),
      avatar: Icon(
        option.icon,
        size: 18,
        color: selected ? AppColors.white : AppColors.primaryTeal,
      ),
      label: Text(
        option.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: selected ? AppColors.white : AppColors.textPrimary,
      ),
      selectedColor: AppColors.primaryTeal,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: selected ? AppColors.primaryTeal : AppColors.outlineStrong,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
    );
  }
}
