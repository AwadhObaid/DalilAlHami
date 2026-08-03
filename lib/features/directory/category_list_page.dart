import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../../models/business.dart';
import '../../models/service_category.dart';
import 'member_details_page.dart';
import 'widgets/business_card.dart';

class CategoryListPage extends StatelessWidget {
  const CategoryListPage({
    required this.categoryName,
    this.categoryId = '',
    super.key,
  });

  final String categoryName;
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final store = DirectoryDataStore.instance;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: Text(categoryName)),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, child) {
          final category = _resolveCategory(store);
          final businesses = category == null
              ? store.businesses
                  .where((business) => business.category == categoryName)
                  .toList(growable: false)
              : store.byCategory(category);

          if (store.isLoading && businesses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (businesses.isEmpty) {
            return RefreshIndicator(
              onRefresh: store.refresh,
              child: _EmptyCategoryState(
                categoryName: categoryName,
                fallbackMessage: store.fallbackMessage,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: store.refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              itemCount:
                  businesses.length + (store.fallbackMessage != null ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(
                height: AppSpacing.sm,
              ),
              itemBuilder: (context, index) {
                if (store.fallbackMessage != null && index == 0) {
                  return _DataSourceNotice(
                    message: store.fallbackMessage!,
                    onRefresh: store.refresh,
                  );
                }

                final businessIndex =
                    index - (store.fallbackMessage != null ? 1 : 0);
                final business = businesses[businessIndex];

                return BusinessCard(
                  business: business,
                  onOpen: () => _openBusiness(context, business),
                );
              },
            ),
          );
        },
      ),
    );
  }

  ServiceCategory? _resolveCategory(DirectoryDataStore store) {
    for (final category in store.categories) {
      if (categoryId.isNotEmpty && category.id == categoryId) {
        return category;
      }

      if (category.name == categoryName) {
        return category;
      }
    }

    return null;
  }

  void _openBusiness(
    BuildContext context,
    Business business,
  ) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => MemberDetailsPage(
          business: business,
        ),
      ),
    );
  }
}

class _DataSourceNotice extends StatelessWidget {
  const _DataSourceNotice({
    required this.message,
    required this.onRefresh,
  });

  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.primaryTeal,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryDark,
              ),
            ),
          ),
          IconButton(
            tooltip: 'إعادة المحاولة',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyCategoryState extends StatelessWidget {
  const _EmptyCategoryState({
    required this.categoryName,
    this.fallbackMessage,
  });

  final String categoryName;
  final String? fallbackMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: 70),
        Container(
          width: 86,
          height: 86,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.storefront_outlined,
            color: AppColors.primaryTeal,
            size: 42,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'لا توجد أنشطة حاليًا',
          style: AppTextStyles.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'لم تُضف بيانات معتمدة إلى قسم $categoryName بعد.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        if (fallbackMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            fallbackMessage!,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.warning,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          'اسحب إلى الأسفل لمحاولة تحديث البيانات.',
          style: AppTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
