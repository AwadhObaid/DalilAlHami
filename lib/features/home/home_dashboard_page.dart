import 'package:flutter/material.dart';

import '../../core/constants/app_catalog.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/launch_actions.dart';
import '../../data/directory_data_store.dart';
import '../../models/business.dart';
import '../../models/directory_advertisement.dart';
import '../../models/service_category.dart';
import '../directory/all_businesses_page.dart';
import '../directory/categories_overview_page.dart';
import '../directory/category_list_page.dart';
import '../directory/member_details_page.dart';
import '../shared/widgets/directory_loading_skeleton.dart';
import '../shared/widgets/directory_status_banner.dart';
import '../shared/widgets/inline_advertisement_banner.dart';
import 'widgets/sticky_advertisement_header.dart';
import 'widgets/category_circle_item.dart';
import 'widgets/home_business_card.dart';
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
  static const ServiceCategory _transportHub = ServiceCategory(
    id: 'featured-transport-hub',
    name: 'خدمات النقل',
    slug: 'transport-hub',
    iconName: 'local_taxi',
    sortOrder: -1,
    displayGroup: CategoryDisplayGroup.transport,
  );

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

  List<ServiceCategory> get _featuredCategories {
    const preferredSlugs = [
      'salons',
      'restaurants',
      'pharmacies',
      'groceries',
      'workshops',
      'fuel-stations',
    ];

    final services = _serviceCategories;
    final result = <ServiceCategory>[_transportHub];

    for (final slug in preferredSlugs) {
      for (final category in services) {
        if (category.slug == slug &&
            !result.any((value) => value.id == category.id)) {
          result.add(category);
          break;
        }
      }
    }

    for (final category in services) {
      if (result.length >= 8) {
        break;
      }
      if (!result.any((value) => value.id == category.id)) {
        result.add(category);
      }
    }

    return result;
  }

  List<Business> get _nearbyBusinesses {
    final values = _directoryStore.businesses
        .where((business) => !business.isDeleted)
        .toList(growable: true);

    values.sort((first, second) {
      if (first.isFeatured != second.isFeatured) {
        return first.isFeatured ? -1 : 1;
      }

      final firstUpdated = first.updatedAt ?? first.createdAt;
      final secondUpdated = second.updatedAt ?? second.createdAt;
      if (firstUpdated != null && secondUpdated != null) {
        return secondUpdated.compareTo(firstUpdated);
      }

      return first.displayName.compareTo(second.displayName);
    });

    return values.take(5).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ColoredBox(
      key: const ValueKey<String>('home-safe-area-shell'),
      color: AppColors.primaryTeal,
      child: SafeArea(
        bottom: false,
        child: ColoredBox(
          color: AppColors.pageBackground,
          child: AnimatedBuilder(
            animation: _directoryStore,
            builder: (context, child) {
              if (_directoryStore.isInitialLoading) {
                return Column(
                  children: [
                    HomeHeader(
                      onOpenSearch: widget.onOpenSearch,
                      onOpenFilters: () => _openCategoriesOverview(),
                    ),
                    const Expanded(
                      child: DirectoryLoadingSkeleton(itemCount: 3),
                    ),
                  ],
                );
              }

              return _buildContent();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final businesses = _nearbyBusinesses;
    final homeTopAdvertisements =
        _directoryStore.advertisementsForPlacement('home_top');
    final homeMiddleAdvertisements =
        _directoryStore.advertisementsForPlacement('home_middle');

    return RefreshIndicator(
      onRefresh: _directoryStore.refresh,
      child: CustomScrollView(
        key: const PageStorageKey<String>('home-dashboard-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: HomeHeader(
              onOpenSearch: widget.onOpenSearch,
              onOpenFilters: () => _openCategoriesOverview(),
            ),
          ),
          if (_directoryStore.isRefreshing)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2),
            ),
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
            advertisements: homeTopAdvertisements
                .map((advertisement) => advertisement.title)
                .toList(growable: false),
            imagePaths: homeTopAdvertisements
                .map((advertisement) => advertisement.imagePath)
                .toList(growable: false),
            compactImagePaths: homeTopAdvertisements
                .map((advertisement) => advertisement.compactImagePath)
                .toList(growable: false),
            onAdvertisementTap: (index) {
              if (index < 0 || index >= homeTopAdvertisements.length) {
                return;
              }
              _openAdvertisement(homeTopAdvertisements[index]);
            },
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.lg),
          ),
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'الفئات المميزة',
              icon: Icons.workspace_premium_outlined,
              viewAllKey: 'featured-categories-view-all',
              onViewAll: () => _openCategoriesOverview(),
            ),
          ),
          SliverToBoxAdapter(child: _buildFeaturedCategories()),
          if (homeMiddleAdvertisements.isNotEmpty)
            SliverToBoxAdapter(
              child: InlineAdvertisementBanner(
                advertisements: homeMiddleAdvertisements,
                onOpen: _openAdvertisement,
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.lg),
          ),
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'أنشطة قريبة منك',
              icon: Icons.location_on_outlined,
              viewAllKey: 'nearby-businesses-view-all',
              onViewAll: _openAllBusinesses,
            ),
          ),
          if (businesses.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyBusinesses())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) {
                    return const SizedBox(height: AppSpacing.sm);
                  }

                  final business = businesses[index ~/ 2];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: HomeBusinessCard(
                      business: business,
                      onOpen: () => _openBusiness(business),
                    ),
                  );
                },
                childCount: (businesses.length * 2) - 1,
              ),
            ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: _ExploreDirectoryFooter(
              onOpenAllBusinesses: _openAllBusinesses,
              onOpenCategories: () => _openCategoriesOverview(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCategories() {
    final categories = _featuredCategories;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final listHeight = (116 + ((textScale - 1) * 84)).clamp(116.0, 152.0);

    return SizedBox(
      key: const ValueKey<String>('featured-category-list'),
      height: listHeight,
      child: ListView.separated(
        key: const PageStorageKey<String>('featured-categories'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 2),
        itemBuilder: (context, index) {
          final category = categories[index];

          return CategoryCircleItem(
            category: category,
            accentIndex: index,
            emphasized: index == 0,
            onTap: category.id == _transportHub.id
                ? () => _openCategoriesOverview(
                      initialGroup: CategoryDisplayGroup.transport,
                    )
                : () => _openCategory(category),
          );
        },
      ),
    );
  }

  Widget _buildEmptyBusinesses() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 42,
              color: AppColors.primaryTeal,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'ستظهر الأنشطة المسجلة هنا',
              style: AppTextStyles.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'حدّث بيانات الدليل أو استخدم البحث للوصول إلى نشاط محدد.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAllBusinesses() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const AllBusinessesPage(),
      ),
    );
  }

  Future<void> _openCategoriesOverview({
    CategoryDisplayGroup initialGroup = CategoryDisplayGroup.services,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => CategoriesOverviewPage(
          initialGroup: initialGroup,
        ),
      ),
    );
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

  void _openAdvertisement(DirectoryAdvertisement advertisement) {
    final businessId = advertisement.businessId?.trim();
    if (businessId != null && businessId.isNotEmpty) {
      for (final business in _directoryStore.businesses) {
        if (business.id == businessId && !business.isDeleted) {
          _openBusiness(business);
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

  void _openBusiness(Business business) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => MemberDetailsPage(business: business),
      ),
    );
  }
}

class _ExploreDirectoryFooter extends StatelessWidget {
  const _ExploreDirectoryFooter({
    required this.onOpenAllBusinesses,
    required this.onOpenCategories,
  });

  final VoidCallback onOpenAllBusinesses;
  final VoidCallback onOpenCategories;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSizes.bottomBarHeight + AppSpacing.md,
        ),
        child: Container(
          key: const ValueKey<String>('home-explore-directory-footer'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.explore_outlined,
                  color: AppColors.primaryTeal,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'استكشف دليل الحامي',
                      style: AppTextStyles.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'تصفح جميع الأنشطة أو انتقل إلى الأقسام.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'خيارات الاستكشاف',
                onSelected: (value) {
                  if (value == 'all') {
                    onOpenAllBusinesses();
                  } else {
                    onOpenCategories();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'all',
                    child: Text('جميع الأنشطة'),
                  ),
                  PopupMenuItem(
                    value: 'categories',
                    child: Text('الأقسام'),
                  ),
                ],
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.primaryTeal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.viewAllKey,
    required this.onViewAll,
  });

  final String title;
  final IconData icon;
  final String viewAllKey;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primaryTeal,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(title, style: AppTextStyles.titleLarge),
          ),
          TextButton(
            key: ValueKey<String>(viewAllKey),
            onPressed: onViewAll,
            child: const Text('عرض الكل'),
          ),
        ],
      ),
    );
  }
}
