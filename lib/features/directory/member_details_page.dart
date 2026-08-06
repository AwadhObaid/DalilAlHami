import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/launch_actions.dart';
import '../../models/business.dart';
import 'widgets/business_gallery_section.dart';
import 'widgets/business_image.dart';

class MemberDetailsPage extends StatelessWidget {
  const MemberDetailsPage({
    required this.business,
    super.key,
  });

  final Business business;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildIdentityCard(),
                  const SizedBox(height: AppSpacing.md),
                  _buildQuickActions(context),
                  const SizedBox(height: AppSpacing.md),
                  _buildInformationCard(context),
                  const SizedBox(height: AppSpacing.md),
                  _buildDescriptionCard(),
                  if (business.activeGalleryImages.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildGalleryCard(),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _buildTrustNote(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(context),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 244,
      title: Text(
        business.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          tooltip: 'نسخ رقم التواصل',
          onPressed: business.hasPhone ? () => _copyPhone(context) : null,
          icon: const Icon(Icons.copy_rounded),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            BusinessImage(
              business: business,
              heroEnabled: true,
              iconSize: 72,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x22000000),
                    Color(0x88000000),
                  ],
                  stops: [0.45, 1],
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.md,
              left: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      business.displayCategory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  if (business.isFeatured)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightTeal,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.primaryDark,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            'مميز',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppColors.primaryTeal,
              size: 29,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business.displayName,
                  style: AppTextStyles.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            label: 'اتصال',
            icon: Icons.phone_rounded,
            color: AppColors.primaryTeal,
            enabled: business.hasPhone,
            onPressed: () {
              LaunchActions.makePhoneCall(context, business.phone);
            },
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _QuickAction(
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
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _QuickAction(
            label: 'نسخ الرقم',
            icon: Icons.copy_rounded,
            color: AppColors.textSecondary,
            enabled: business.hasPhone,
            onPressed: () => _copyPhone(context),
          ),
        ),
      ],
    );
  }

  Widget _buildInformationCard(BuildContext context) {
    return _SectionCard(
      title: 'معلومات التواصل',
      icon: Icons.contact_phone_outlined,
      child: Column(
        children: [
          _InformationRow(
            icon: Icons.category_outlined,
            label: 'القسم',
            value: business.displayCategory,
          ),
          const Divider(),
          _InformationRow(
            icon: Icons.location_on_outlined,
            label: 'العنوان',
            value: business.displayPlace,
          ),
          const Divider(),
          _InformationRow(
            icon: Icons.phone_outlined,
            label: 'رقم الاتصال',
            value: business.hasPhone ? business.phone.trim() : 'غير متوفر',
            onTap: business.hasPhone
                ? () {
                    LaunchActions.makePhoneCall(
                      context,
                      business.phone,
                    );
                  }
                : null,
          ),
          const Divider(),
          _InformationRow(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'رقم واتساب',
            value:
                business.hasWhatsApp ? business.whatsappContact : 'غير متوفر',
            onTap: business.hasWhatsApp
                ? () {
                    LaunchActions.openWhatsApp(
                      context,
                      business.whatsappContact,
                      message: 'مرحبًا، تواصلت معكم عبر دليل الحامي '
                          'بخصوص ${business.displayName}.',
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return _SectionCard(
      title: 'نبذة عن النشاط',
      icon: Icons.description_outlined,
      child: Text(
        business.displayDetails.isEmpty
            ? 'لم يُضف صاحب النشاط وصفًا تفصيليًا حتى الآن.'
            : business.displayDetails,
        style: AppTextStyles.bodyLarge.copyWith(
          color: business.displayDetails.isEmpty
              ? AppColors.textMuted
              : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildGalleryCard() {
    return _SectionCard(
      title: 'صور النشاط',
      icon: Icons.photo_library_outlined,
      child: BusinessGallerySection(images: business.activeGalleryImages),
    );
  }

  Widget _buildTrustNote() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primaryTeal,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'تعرض الصفحة المعلومات المنشورة في دليل الحامي. '
              'يمكنك التواصل مع النشاط للتأكد من المواعيد والخدمات.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.outline),
          ),
          boxShadow: AppShadows.floating,
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: business.hasPhone
                    ? () {
                        LaunchActions.makePhoneCall(
                          context,
                          business.phone,
                        );
                      }
                    : null,
                icon: const Icon(Icons.phone_rounded),
                label: const Text('اتصال الآن'),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: business.hasWhatsApp
                    ? () {
                        LaunchActions.openWhatsApp(
                          context,
                          business.whatsappContact,
                          message: 'مرحبًا، تواصلت معكم عبر دليل الحامي '
                              'بخصوص ${business.displayName}.',
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.whatsapp,
                ),
                icon: const Icon(Icons.chat_bubble_rounded),
                label: const Text('واتساب'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyPhone(BuildContext context) async {
    if (!business.hasPhone) {
      LaunchActions.showMessage(
        context,
        'لا يتوفر رقم اتصال لنسخه.',
      );
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: business.phone.trim()),
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
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: AppColors.primaryTeal,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: AppColors.primaryTeal,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 15,
              color: AppColors.textMuted,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: content,
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
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
    return Material(
      color: enabled ? color.withValues(alpha: 0.09) : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 76,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: enabled ? color : AppColors.textMuted,
                  size: 24,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: enabled ? color : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
