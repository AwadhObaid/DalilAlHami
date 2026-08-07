import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_catalog.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/launch_actions.dart';
import '../../data/directory_data_store.dart';
import '../../models/directory_advertisement.dart';
import '../../models/service_category.dart';
import '../shared/widgets/directory_loading_skeleton.dart';
import '../shared/widgets/directory_page_header.dart';
import '../shared/widgets/directory_result_summary.dart';
import '../shared/widgets/directory_search_field.dart';
import '../shared/widgets/directory_status_banner.dart';
import '../shared/widgets/inline_advertisement_banner.dart';
import 'category_list_page.dart';
import 'member_details_page.dart';

class CategoriesOverviewPage extends StatefulWidget {
  const CategoriesOverviewPage({
    this.initialGroup = CategoryDisplayGroup.services,
    super.key,
  });

  final CategoryDisplayGroup initialGroup;

  @override
  State<CategoriesOverviewPage> createState() => _CategoriesOverviewPageState();
}

class _CategoriesOverviewPageState extends State<CategoriesOverviewPage>
    with AutomaticKeepAliveClientMixin<CategoriesOverviewPage> {
  final DirectoryDataStore _store = DirectoryDataStore.instance;
  final TextEditingController _searchController = TextEditingController();

  late CategoryDisplayGroup _selectedGroup;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.initialGroup;

    if (!_store.hasLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _store.load();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    super.build(context);

    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      key: const ValueKey<String>('categories-overview-page-shell'),
      backgroundColor: AppColors.pageBackground,
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, child) {
          final categories = _filteredCategories;
          final businessCount = _businessCountForGroup(_selectedGroup);

          return Column(
            key: const ValueKey<String>('categories-overview-layout-column'),
            children: [
              if (!keyboardVisible)
                DirectoryPageHeader(
                  headerKey: 'categories-overview-header',
                  title: 'الأقسام',
                  subtitle: 'تصفح خدمات مدينة الحامي حسب المجال',
                  icon: Icons.grid_view_rounded,
                  onBack: () => Navigator.maybePop(context),
                  action: DirectoryHeaderRefreshButton(
                    isLoading: _store.isLoading,
                    onPressed: _store.refresh,
                  ),
                ),
              if (_store.isRefreshing)
                const LinearProgressIndicator(minHeight: 2),
              _buildGroupSelector(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: DirectorySearchField(
                  controller: _searchController,
                  query: _query,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                  onClear: _clearSearch,
                  fieldKey: 'category-search-field',
                  hintText: AppLocaleText.pick(
                    context,
                    ar: 'ابحث داخل الأقسام…',
                    en: 'Search categories…',
                  ),
                ),
              ),
              DirectoryResultSummary(
                count: categories.length,
                label: _selectedGroup == CategoryDisplayGroup.services
                    ? 'أقسام الخدمات'
                    : 'أقسام النقل',
                icon: _selectedGroup == CategoryDisplayGroup.services
                    ? Icons.storefront_rounded
                    : Icons.route_rounded,
                summaryKey: 'categories-result-summary',
                trailing: Text(
                  '$businessCount نشاط',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primaryTeal,
                  ),
                ),
              ),
              Expanded(
                child: _store.isInitialLoading
                    ? const CategoryLoadingSkeleton()
                    : _buildScrollableBody(
                        categories,
                        fallbackMessage: _store.fallbackMessage,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<ServiceCategory> get _filteredCategories {
    final source = _categoriesForSelectedGroup();
    final query = _normalize(_query);

    if (query.isEmpty) {
      return source;
    }

    return source
        .where((category) => _normalize(category.name).contains(query))
        .toList(growable: false);
  }

  Widget _buildGroupSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: _GroupButton(
                keyName: 'category-group-services',
                label: 'الخدمات والأنشطة',
                icon: Icons.storefront_rounded,
                selected: _selectedGroup == CategoryDisplayGroup.services,
                onPressed: () => _selectGroup(CategoryDisplayGroup.services),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: _GroupButton(
                keyName: 'category-group-transport',
                label: 'خدمات النقل',
                icon: Icons.route_rounded,
                selected: _selectedGroup == CategoryDisplayGroup.transport,
                onPressed: () => _selectGroup(CategoryDisplayGroup.transport),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableBody(
    List<ServiceCategory> categories, {
    required String? fallbackMessage,
  }) {
    return RefreshIndicator(
      onRefresh: _store.refresh,
      child: CustomScrollView(
        key: PageStorageKey<String>(
          'categories-scrollable-${_selectedGroup.name}',
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (fallbackMessage != null)
            SliverToBoxAdapter(
              child: DirectoryStatusBanner(
                key: const ValueKey<String>('categories-status-banner'),
                message: fallbackMessage,
                isRefreshing: _store.isRefreshing,
                onRetry: _store.refresh,
              ),
            ),
          if (_store.advertisementsForPlacement('category').isNotEmpty)
            SliverToBoxAdapter(
              child: InlineAdvertisementBanner(
                advertisements: _store.advertisementsForPlacement('category'),
                onOpen: _openAdvertisement,
              ),
            ),
          if (categories.isEmpty)
            SliverToBoxAdapter(
              child: _buildEmptyCategoriesState(),
            )
          else
            _buildCategoryGridSliver(categories),
          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCategoriesState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        48,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.category_outlined,
            size: 62,
            color: AppColors.primaryTeal,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _query.trim().isEmpty
                ? 'لا توجد أقسام متاحة حاليًا'
                : 'لا يوجد قسم مطابق لبحثك',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _query.trim().isEmpty
                ? 'اسحب إلى الأسفل لإعادة تحميل البيانات.'
                : 'جرّب كلمة أقصر أو امسح البحث.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
          if (_query.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.close_rounded),
              label: const Text('مسح البحث'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryGridSliver(
    List<ServiceCategory> categories,
  ) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.crossAxisExtent;
        final crossAxisCount = availableWidth < 360
            ? 2
            : availableWidth < 700
                ? 3
                : 4;
        final requestedTextScale = MediaQuery.textScalerOf(context).scale(1);
        final textScale = requestedTextScale.clamp(1.0, 1.4);
        final baseCardExtent = crossAxisCount == 2 ? 164.0 : 158.0;
        final cardExtent = (baseCardExtent + ((textScale - 1) * 120))
            .clamp(baseCardExtent, 220.0);

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            0,
          ),
          sliver: SliverGrid(
            key: ValueKey<String>(
              'categories-grid-${_selectedGroup.name}',
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisExtent: cardExtent,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final category = categories[index];
                final count = _store.byCategory(category).length;

                return CategoryOverviewCard(
                  key: ValueKey<String>('category-card-${category.id}'),
                  category: category,
                  businessCount: count,
                  accentIndex: index,
                  onTap: () => _openCategory(category),
                );
              },
              childCount: categories.length,
            ),
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

  int _businessCountForGroup(CategoryDisplayGroup group) {
    final categories = group == CategoryDisplayGroup.services
        ? _store.serviceCategories
        : _store.transportCategories;

    return _store.businesses.where((business) {
      if (business.isDeleted) {
        return false;
      }

      return categories.any(
        (category) => business.belongsToCategory(
          id: category.id,
          name: category.name,
        ),
      );
    }).length;
  }

  void _selectGroup(CategoryDisplayGroup group) {
    FocusManager.instance.primaryFocus?.unfocus();
    _searchController.clear();

    setState(() {
      _selectedGroup = group;
      _query = '';
    });
  }

  void _clearSearch() {
    _searchController.clear();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _query = '';
    });
  }

  void _openAdvertisement(DirectoryAdvertisement advertisement) {
    final businessId = advertisement.businessId?.trim();
    if (businessId != null && businessId.isNotEmpty) {
      for (final business in _store.businesses) {
        if (business.id == businessId && !business.isDeleted) {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => MemberDetailsPage(business: business),
            ),
          );
          return;
        }
      }

      LaunchActions.showMessage(context, 'لم يعد النشاط المرتبط متاحًا.');
      return;
    }

    final targetUrl = advertisement.targetUrl?.trim();
    if (targetUrl != null && targetUrl.isNotEmpty) {
      LaunchActions.openExternalUrl(context, targetUrl);
    }
  }

  void _openCategory(ServiceCategory category) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => CategoryListPage(
          categoryName: category.name,
          categoryId: category.id,
          categoryIcon: category.icon,
        ),
      ),
    );
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
  }
}

class _GroupButton extends StatelessWidget {
  const _GroupButton({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String keyName;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Material(
      key: ValueKey<String>(keyName),
      color: selected ? AppColors.primaryTeal : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.minimumTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? AppColors.white : AppColors.primaryTeal,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: selected ? AppColors.white : AppColors.textPrimary,
                    ),
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

class CategoryOverviewCard extends StatelessWidget {
  const CategoryOverviewCard({
    required this.category,
    required this.businessCount,
    required this.onTap,
    this.accentIndex = 0,
    super.key,
  });

  final ServiceCategory category;
  final int businessCount;
  final VoidCallback onTap;
  final int accentIndex;

  static List<Color> get _accentBackgrounds => [
        AppColors.primarySoft,
        AppColors.categoryBlueSoft,
        AppColors.categoryRoseSoft,
        AppColors.categoryLavenderSoft,
        AppColors.categoryPeachSoft,
        AppColors.categoryLimeSoft,
      ];

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final accent =
        _accentBackgrounds[accentIndex.abs() % _accentBackgrounds.length];

    return Semantics(
      button: true,
      label: 'فتح قسم ${category.name}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outline),
          boxShadow: AppShadows.subtle,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                key: ValueKey<String>(
                  'category-card-layout-${category.id}',
                ),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          category.icon,
                          color: AppColors.primaryTeal,
                          size: 27,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Text(
                        category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleSmall.copyWith(
                          height: 1.25,
                        ),
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
                      fontWeight: FontWeight.w700,
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
