import 'package:flutter/material.dart';

import '../../core/constants/app_catalog.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../../models/service_category.dart';
import '../shared/widgets/directory_loading_skeleton.dart';
import '../shared/widgets/directory_status_banner.dart';
import '../shared/widgets/page_header.dart';
import 'category_list_page.dart';

class CategoriesOverviewPage extends StatefulWidget {
  const CategoriesOverviewPage({super.key});

  @override
  State<CategoriesOverviewPage> createState() => _CategoriesOverviewPageState();
}

class _CategoriesOverviewPageState extends State<CategoriesOverviewPage>
    with AutomaticKeepAliveClientMixin<CategoriesOverviewPage> {
  final DirectoryDataStore _store = DirectoryDataStore.instance;
  CategoryDisplayGroup _selectedGroup = CategoryDisplayGroup.services;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    if (!_store.hasLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _store.load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AnimatedBuilder(
      animation: _store,
      builder: (context, child) {
        final categories = _categoriesForSelectedGroup();

        return Column(
          children: [
            PageHeader(
              title: 'الأقسام',
              subtitle: 'تصفح خدمات مدينة الحامي حسب المجال',
              icon: Icons.grid_view_rounded,
              action: IconButton.filledTonal(
                tooltip: 'تحديث الأقسام',
                onPressed: _store.isLoading ? null : _store.refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            if (_store.isRefreshing)
              const LinearProgressIndicator(minHeight: 2),
            _buildGroupSelector(),
            if (_store.fallbackMessage != null)
              DirectoryStatusBanner(
                message: _store.fallbackMessage!,
                isRefreshing: _store.isRefreshing,
                onRetry: _store.refresh,
              ),
            Expanded(
              child: _store.isInitialLoading
                  ? const CategoryLoadingSkeleton()
                  : _buildGrid(categories),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: _GroupButton(
              label: 'الخدمات والأنشطة',
              icon: Icons.storefront_rounded,
              selected: _selectedGroup == CategoryDisplayGroup.services,
              onPressed: () {
                setState(() {
                  _selectedGroup = CategoryDisplayGroup.services;
                });
              },
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _GroupButton(
              label: 'خدمات النقل',
              icon: Icons.route_rounded,
              selected: _selectedGroup == CategoryDisplayGroup.transport,
              onPressed: () {
                setState(() {
                  _selectedGroup = CategoryDisplayGroup.transport;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<ServiceCategory> categories) {
    if (categories.isEmpty) {
      return RefreshIndicator(
        onRefresh: _store.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            72,
            AppSpacing.xl,
            130,
          ),
          children: [
            const Icon(
              Icons.category_outlined,
              size: 70,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'لا توجد أقسام متاحة حاليًا',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'اسحب إلى الأسفل لإعادة تحميل البيانات.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 360
            ? 2
            : constraints.maxWidth < 700
                ? 3
                : 4;
        final requestedTextScale = MediaQuery.textScalerOf(context).scale(1);
        final textScale = requestedTextScale.clamp(1.0, 1.4);
        final baseCardExtent = crossAxisCount == 2 ? 144.0 : 142.0;
        final cardExtent = (baseCardExtent + ((textScale - 1) * 72))
            .clamp(baseCardExtent, 172.0);

        return RefreshIndicator(
          onRefresh: _store.refresh,
          child: GridView.builder(
            key: PageStorageKey<String>(
              'categories-${_selectedGroup.name}',
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              130,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisExtent: cardExtent,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final count = _store.byCategory(category).length;

              return CategoryOverviewCard(
                category: category,
                businessCount: count,
                onTap: () => _openCategory(category),
              );
            },
          ),
        );
      },
    );
  }

  List<ServiceCategory> _categoriesForSelectedGroup() {
    final values = _selectedGroup == CategoryDisplayGroup.services
        ? _store.serviceCategories
        : _store.transportCategories;

    if (values.isNotEmpty) {
      return values;
    }

    return _selectedGroup == CategoryDisplayGroup.services
        ? AppCatalog.services
        : AppCatalog.transport;
  }

  void _openCategory(ServiceCategory category) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => CategoryListPage(
          categoryName: category.name,
          categoryId: category.id,
        ),
      ),
    );
  }
}

class _GroupButton extends StatelessWidget {
  const _GroupButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final buttonHeight = (52 + ((textScale - 1) * 24)).clamp(52.0, 64.0);

    return SizedBox(
      height: buttonHeight,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? AppColors.white : AppColors.primaryTeal,
          backgroundColor: selected ? AppColors.primaryTeal : AppColors.surface,
          side: BorderSide(
            color: selected ? AppColors.primaryTeal : AppColors.outlineStrong,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class CategoryOverviewCard extends StatelessWidget {
  const CategoryOverviewCard({
    required this.category,
    required this.businessCount,
    required this.onTap,
    super.key,
  });

  final ServiceCategory category;
  final int businessCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'فتح قسم ${category.name}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.outline),
          boxShadow: AppShadows.subtle,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      category.icon,
                      color: AppColors.primaryTeal,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    businessCount == 0
                        ? 'لا توجد بيانات'
                        : '$businessCount نشاط',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: businessCount == 0
                          ? AppColors.textMuted
                          : AppColors.primaryTeal,
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
}
