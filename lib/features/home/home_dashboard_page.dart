import 'package:flutter/material.dart';

import '../../core/constants/app_catalog.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/launch_actions.dart';
import '../../data/directory_data_store.dart';
import '../../models/service_category.dart';
import '../directory/category_list_page.dart';
import '../shared/widgets/directory_loading_skeleton.dart';
import '../shared/widgets/directory_status_banner.dart';
import 'widgets/sticky_advertisement_header.dart';
import 'widgets/category_circle_item.dart';
import 'widgets/home_header.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({
    required this.onOpenSearch,
    required this.onOpenCategories,
    super.key,
  });

  final VoidCallback onOpenSearch;
  final VoidCallback onOpenCategories;

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage>
    with AutomaticKeepAliveClientMixin<HomeDashboardPage> {
  final DirectoryDataStore _directoryStore = DirectoryDataStore.instance;
  final PageController _adPageController = PageController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    if (!_directoryStore.hasLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _directoryStore.load();
      });
    }
  }

  @override
  void dispose() {
    _adPageController.dispose();
    super.dispose();
  }

  List<ServiceCategory> get _serviceCategories {
    final values = _directoryStore.serviceCategories;
    return values.isNotEmpty ? values : AppCatalog.services;
  }

  List<ServiceCategory> get _transportCategories {
    final values = _directoryStore.transportCategories;
    return values.isNotEmpty ? values : AppCatalog.transport;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AnimatedBuilder(
      animation: _directoryStore,
      builder: (context, child) {
        return Column(
          children: [
            const HomeHeader(),
            if (_directoryStore.isRefreshing)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _directoryStore.isInitialLoading
                  ? const DirectoryLoadingSkeleton(itemCount: 3)
                  : _buildContent(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _directoryStore.refresh,
      child: CustomScrollView(
        key: const PageStorageKey<String>('home-dashboard-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildSearchLauncher()),
          if (_directoryStore.fallbackMessage != null)
            SliverToBoxAdapter(
              child: DirectoryStatusBanner(
                message: _directoryStore.fallbackMessage!,
                isRefreshing: _directoryStore.isRefreshing,
                onRetry: _directoryStore.refresh,
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.sm),
          ),
          StickyAdvertisementHeader(
            controller: _adPageController,
            advertisements: _directoryStore.advertisements,
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.lg),
          ),
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              title: 'خدمات النقل',
              subtitle: 'وصول أسرع للخدمات اليومية',
              icon: Icons.route_rounded,
              onViewAll: widget.onOpenCategories,
            ),
          ),
          SliverToBoxAdapter(child: _buildHorizontalCategories()),
          SliverToBoxAdapter(child: _buildSuggestionBox()),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xs),
          ),
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              title: 'الخدمات والأنشطة',
              subtitle: 'اختر القسم الذي تبحث عنه',
              icon: Icons.grid_view_rounded,
              onViewAll: widget.onOpenCategories,
            ),
          ),
          SliverToBoxAdapter(child: _buildServiceGrid()),
          const SliverToBoxAdapter(child: SizedBox(height: 132)),
        ],
      ),
    );
  }

  Widget _buildSearchLauncher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        elevation: 0,
        child: InkWell(
          key: const ValueKey<String>('home-search-launcher'),
          onTap: widget.onOpenSearch,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.outline),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: AppColors.primaryTeal,
                  size: 27,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'ابحث عن مطعم، صيدلية، ورشة أو اسم نشاط…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onViewAll,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
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
              color: AppColors.primaryTeal,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          TextButton(
            onPressed: onViewAll,
            child: const Text('عرض الكل'),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCategories() {
    final categories = _transportCategories;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final listHeight = (106 + ((textScale - 1) * 90)).clamp(
      106.0,
      142.0,
    );

    return SizedBox(
      key: const ValueKey<String>('transport-category-list'),
      height: listHeight,
      child: ListView.separated(
        key: const PageStorageKey<String>('transport-categories'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(
          width: AppSpacing.xxs,
        ),
        itemBuilder: (context, index) {
          final category = categories[index];

          return CategoryCircleItem(
            category: category,
            onTap: () => _openCategory(category),
          );
        },
      ),
    );
  }

  Widget _buildSuggestionBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Container(
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
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.mintSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'شكرًا لاختيارك دليل الحامي',
                    style: AppTextStyles.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'اقتراحك يساعدنا على تطوير الدليل وتحسين خدماته.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton.filled(
              tooltip: 'إرسال اقتراح عبر واتساب',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: AppColors.white,
              ),
              onPressed: () {
                LaunchActions.openWhatsApp(
                  context,
                  '772551846',
                  message: 'لدي اقتراح لتطوير تطبيق دليل الحامي.',
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceGrid() {
    final categories = _serviceCategories;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 360 ? 2 : 3;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final baseAspectRatio = crossAxisCount == 2 ? 1.12 : 0.96;
        final adaptiveAspectRatio =
            (baseAspectRatio / (1 + ((textScale - 1) * 0.75)))
                .clamp(0.72, baseAspectRatio);

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.md,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: adaptiveAspectRatio,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];

            return Semantics(
              button: true,
              label: 'فتح قسم ${category.name}',
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.outline),
                  boxShadow: AppShadows.subtle,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    onTap: () => _openCategory(category),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: index.isEven
                                  ? AppColors.primarySoft
                                  : AppColors.mintSoft,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(
                              category.icon,
                              color: AppColors.primaryTeal,
                              size: 25,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            category.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
