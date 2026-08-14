import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/launch_actions.dart';
import '../../../models/business.dart';
import '../../../models/business_contact_number.dart';

abstract final class BusinessContactActions {
  static bool requiresPhonePicker(Business business) =>
      business.effectiveContactNumbers.length > 1;

  static Future<void> call(
    BuildContext context,
    Business business,
  ) async {
    final contact = await _resolveContact(
      context,
      business,
      title: 'اختر رقم الاتصال',
      actionIcon: Icons.phone_rounded,
    );
    if (contact == null || !context.mounted) {
      return;
    }

    await LaunchActions.makePhoneCall(
      context,
      contact.trimmedPhoneNumber,
    );
  }

  static Future<void> copy(
    BuildContext context,
    Business business,
  ) async {
    final contact = await _resolveContact(
      context,
      business,
      title: 'اختر الرقم لنسخه',
      actionIcon: Icons.copy_rounded,
    );
    if (contact == null) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: contact.trimmedPhoneNumber),
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ رقم التواصل.',
          textAlign: TextAlign.center,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<BusinessContactNumber?> _resolveContact(
    BuildContext context,
    Business business, {
    required String title,
    required IconData actionIcon,
  }) async {
    final contacts = business.effectiveContactNumbers;
    if (contacts.isEmpty) {
      LaunchActions.showMessage(
        context,
        'لا يتوفر رقم اتصال لهذا النشاط.',
      );
      return null;
    }

    if (contacts.length == 1) {
      return contacts.single;
    }

    return showModalBottomSheet<BusinessContactNumber>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        AppColors.bindToTheme(sheetContext);
        return _BusinessContactPickerSheet(
          title: title,
          contacts: contacts,
          actionIcon: actionIcon,
        );
      },
    );
  }
}

class _BusinessContactPickerSheet extends StatelessWidget {
  const _BusinessContactPickerSheet({
    required this.title,
    required this.contacts,
    required this.actionIcon,
  });

  final String title;
  final List<BusinessContactNumber> contacts;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'اضغط على الرقم المطلوب للمتابعة.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < contacts.length; index++) ...[
            _BusinessContactPickerTile(
              contact: contacts[index],
              actionIcon: actionIcon,
            ),
            if (index != contacts.length - 1)
              const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _BusinessContactPickerTile extends StatelessWidget {
  const _BusinessContactPickerTile({
    required this.contact,
    required this.actionIcon,
  });

  final BusinessContactNumber contact;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);

    return Material(
      color: contact.isPrimary ? AppColors.primarySoft : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        key: ValueKey<String>('business-contact-picker-${contact.id}'),
        onTap: () {
          Navigator.of(context).pop(contact);
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  actionIcon,
                  color: AppColors.primaryTeal,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      key: ValueKey<String>(
                        'business-contact-picker-number-${contact.id}',
                      ),
                      contact.trimmedPhoneNumber,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (contact.supportsWhatsApp) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.whatsapp.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chat_bubble_rounded,
                        size: 14,
                        color: AppColors.whatsapp,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        'واتساب',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.whatsapp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
