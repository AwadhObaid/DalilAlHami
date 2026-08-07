import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';

class DirectoryResultSummary extends StatelessWidget {
  const DirectoryResultSummary({
    required this.count,
    required this.label,
    required this.icon,
    this.trailing,
    this.summaryKey,
    super.key,
  });

  final int count;
  final String label;
  final IconData icon;
  final Widget? trailing;
  final String? summaryKey;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Padding(
      key: summaryKey == null ? null : ValueKey<String>(summaryKey!),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 19,
              color: AppColors.primaryTeal,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '$label: $count',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleSmall,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
