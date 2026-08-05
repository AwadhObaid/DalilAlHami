import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../../models/business.dart';
import '../../models/service_category.dart';
import '../shared/widgets/directory_filter_bar.dart';
import '../shared/widgets/directory_loading_skeleton.dart';
import '../shared/widgets/directory_page_header.dart';
import '../shared/widgets/directory_result_summary.dart';
import '../shared/widgets/directory_search_field.dart';
import '../shared/widgets/directory_status_banner.dart';
import 'member_details_page.dart';
import 'widgets/business_card.dart';

class AllBusinessesPage extends StatefulWidget {
  const AllBusinessesPage({super.key});

  @override
  State<AllBusinessesPage> createState() => _AllBusinessesPageState();
}

class _AllBusinessesPageState extends State<AllBusinessesPage> {
  static const List<DirectoryFilterOption> _filterOptions = [
    DirectoryFilterOption(
      id: 'all-businesses',
      label: 'الكل',
      icon: Icons.apps_rounded,
    ),
    DirectoryFilterOption(
      id: 'featured-businesses',
      label: 'المميزة',
      icon: Icons.verified_rounded,
    ),
    DirectoryFilterOption(
      id: 'service-businesses',
      label: 'الخدمات',
      icon: Icons.storefront_rounded,
    ),
    DirectoryFilterOption(
      id: 'transport-businesses',
      label: 'النقل',
      icon: Icons.route_rounded,
    ),
  ];

  final DirectoryDataStore _store = DirectoryDataStore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String _selectedFilter = 'all-businesses';

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      key: const ValueKey<String>('all-businesses-page-shell'),
      backgroundColor: AppColors.pageBackground,
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, child) {
          final businesses = _filteredBusinesses;

          return Column(
            key: const ValueKey<String>('all-businesses-layout-column'),
            children: [
              if (!keyboardVisible)
                DirectoryPageHeader(
                  headerKey: 'all-businesses-header',
                  title: 'جميع الأنشطة',
                  subtitle: 'تصفح وابحث في كل الأنشطة المسجلة بالدليل',
                  icon: Icons.storefront_rounded,
                  onBack: () => Navigator.maybePop(context),
                  action: DirectoryHeaderRefreshButton(
                    isLoading: _store.isLoading,
                    onPressed: _store.refresh,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
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
                  fieldKey: 'all-businesses-search-field',
                  hintText: 'ابحث داخل جميع الأنشطة…',
                ),
              ),
              DirectoryFilterBar(
                barKey: 'all-businesses-filters',
                options: _filterOptions,
                selectedId: _selectedFilter,
                onSelected: (value) {
                  setState(() {
                    _selectedFilter = value;
                  });
                },
              ),
              DirectoryResultSummary(
                count: businesses.length,
                label: 'الأنشطة المتاحة',
                icon: Icons.fact_check_outlined,
                summaryKey: 'all-businesses-result-count',
              ),
              if (_store.isRefreshing)
                const LinearProgressIndicator(minHeight: 2),
              if (_store.fallbackMessage != null)
                DirectoryStatusBanner(
                  message: _store.fallbackMessage!,
                  isRefreshing: _store.isRefreshing,
                  onRetry: _store.refresh,
                ),
              Expanded(
                child: _buildBody(businesses),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Business> get _filteredBusinesses {
    final query = _query.trim();
    final values = _store.businesses
        .where((business) => !business.isDeleted)
        .where((business) {
          return query.isEmpty || business.matchesSearch(query);
        })
        .where(_matchesSelectedFilter)
        .toList(growable: true);

    values.sort(_compareBusinesses);
    return values;
  }

  Widget _buildBody(List<Business> businesses) {
    if (_store.isInitialLoading) {
      return const DirectoryLoadingSkeleton();
    }

    return RefreshIndicator(
      onRefresh: _store.refresh,
      child: CustomScrollView(
        key: const PageStorageKey<String>('all-businesses-page'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (businesses.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyBusinessesState(
                hasSearch: _query.trim().isNotEmpty ||
                    _selectedFilter != 'all-businesses',
                onReset: _resetFilters,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              sliver: SliverList.separated(
                itemCount: businesses.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final business = businesses[index];

                  return BusinessCard(
                    key: ValueKey<String>('all-business-${business.id}'),
                    business: business,
                    onOpen: () => _openBusiness(business),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  bool _matchesSelectedFilter(Business business) {
    return switch (_selectedFilter) {
      'featured-businesses' => business.isFeatured,
      'transport-businesses' => _belongsToGroup(
          business,
          CategoryDisplayGroup.transport,
        ),
      'service-businesses' => !_belongsToGroup(
          business,
          CategoryDisplayGroup.transport,
        ),
      _ => true,
    };
  }

  bool _belongsToGroup(
    Business business,
    CategoryDisplayGroup group,
  ) {
    for (final category in _store.categories) {
      if (category.displayGroup == group &&
          business.belongsToCategory(
            id: category.id,
            name: category.name,
          )) {
        return true;
      }
    }

    return false;
  }

  void _clearSearch() {
    _searchController.clear();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _query = '';
    });
  }

  void _resetFilters() {
    _searchController.clear();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _query = '';
      _selectedFilter = 'all-businesses';
    });
  }

  void _openBusiness(Business business) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => MemberDetailsPage(business: business),
      ),
    );
  }

  static int _compareBusinesses(Business first, Business second) {
    if (first.isFeatured != second.isFeatured) {
      return first.isFeatured ? -1 : 1;
    }

    final firstUpdated = first.updatedAt ?? first.createdAt;
    final secondUpdated = second.updatedAt ?? second.createdAt;

    if (firstUpdated != null && secondUpdated != null) {
      return secondUpdated.compareTo(firstUpdated);
    }

    return first.displayName.compareTo(second.displayName);
  }
}

class _EmptyBusinessesState extends StatelessWidget {
  const _EmptyBusinessesState({
    required this.hasSearch,
    required this.onReset,
  });

  final bool hasSearch;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 58,
              color: AppColors.primaryTeal,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              hasSearch ? 'لا توجد أنشطة مطابقة' : 'لا توجد أنشطة متاحة حاليًا',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasSearch
                  ? 'غيّر كلمة البحث أو أعد ضبط الفلاتر.'
                  : 'اسحب إلى الأسفل لتحديث بيانات الدليل.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            if (hasSearch) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('إعادة ضبط البحث'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
