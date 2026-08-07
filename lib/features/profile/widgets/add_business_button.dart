import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';

class AddBusinessButton extends StatelessWidget {
  const AddBusinessButton({
    required this.onPressed,
    this.buttonKey,
    this.label = 'إضافة نشاط جديد',
    super.key,
  });

  final VoidCallback? onPressed;
  final Key? buttonKey;
  final String label;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        icon: const Icon(Icons.add_business_rounded),
        label: Text(
          label,
          style: AppTextStyles.titleSmall.copyWith(
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
