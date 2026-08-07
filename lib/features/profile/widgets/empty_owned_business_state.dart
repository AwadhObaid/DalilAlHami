import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';

class EmptyOwnedBusinessState extends StatelessWidget {
  const EmptyOwnedBusinessState({
    required this.onAddPressed,
    super.key,
  });

  static const ValueKey<String> addButtonKey =
      ValueKey<String>('profile-add-business-button');

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        40,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outline),
          boxShadow: AppShadows.subtle,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_business_rounded,
                size: 46,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'لا يوجد نشاط مسجل في حسابك',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'أضف بيانات نشاطك الآن. عند انقطاع الإنترنت سيُحفظ الطلب '
              'محليًا ويُرسل تلقائيًا عند عودة الاتصال.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: addButtonKey,
                onPressed: onAddPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة نشاط جديد'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
