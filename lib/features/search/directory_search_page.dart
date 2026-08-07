import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../../models/business.dart';
import '../../models/service_category.dart';
import '../directory/member_details_page.dart';
import '../directory/widgets/business_card.dart';
import '../shared/widgets/directory_filter_bar.dart';
import '../shared/widgets/directory_loading_skeleton.dart';
import '../shared/widgets/directory_page_header.dart';
import '../shared/widgets/directory_result_summary.dart';
import '../shared/widgets/directory_search_field.dart';
import '../shared/widgets/directory_status_banner.dart';

class DirectorySearchPage extends StatefulWidget {
  const DirectorySearchPage({super.key});

  @override
  State<DirectorySearchPage> createState() => _DirectorySearchPageState();
}

class _DirectorySearchPageState extends State<DirectorySearchPage>
    with AutomaticKeepAliveClientMixin<DirectorySearchPage> {
  static const List<DirectoryFilterOption> _filterOptions = [
    DirectoryFilterOption(
      id: 'all',
      label: 'الكل',
      icon: Icons.apps_rounded,
    ),
    DirectoryFilterOption(
      id: 'featured',
      label: 'المميزة',
      icon: Icons.verified_rounded,
    ),
    DirectoryFilterOption(
      id: 'services',
      label: 'الخدمات',
      icon: Icons.storefront_rounded,
    ),
    DirectoryFilterOption(
      id: 'transport',
      label: 'النقل',
      icon: Icons.route_rounded,
    ),
  ];

  final DirectoryDataStore _store = DirectoryDataStore.instance;
  final TextEditingController _controller = TextEditingController();

  String _query = '';
  String _selectedFilter = 'all';

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Business> get _results {
    final query = _query.trim();
    if (query.isEmpty) {
      return const [];
    }

    final values = _store
        .search(query)
        .where((business) => !business.isDeleted)
        .where(_matchesSelectedFilter)
        .toList(growable: true);

    values.sort(_compareBusinesses);
    return values;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    super.build(context);

    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Material(
      key: const ValueKey<String>('directory-search-page-shell'),
      color: AppColors.pageBackground,
      child: AnimatedBuilder(
        animation: _store,
        builder: (context, child) {
          final results = _results;

          return Column(
            children: [
              if (!keyboardVisible)
                DirectoryPageHeader(
                  headerKey: 'directory-search-header',
                  title: 'البحث',
                  subtitle: 'ابحث بالاسم أو القسم أو العنوان أو رقم الهاتف',
                  icon: Icons.manage_search_rounded,
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
                  controller: _controller,
                  query: _query,
                  onChanged: _search,
                  onClear: _clearSearch,
                  fieldKey: 'directory-search-field',
                  hintText: AppLocaleText.pick(
                    context,
                    ar: 'ابحث عن مطعم، صيدلية، ورشة أو اسم نشاط…',
                    en: 'Search for a restaurant, pharmacy, workshop, or business…',
                  ),
                ),
              ),
              DirectoryFilterBar(
                barKey: 'directory-search-filters',
                options: _filterOptions,
                selectedId: _selectedFilter,
                onSelected: (value) {
                  setState(() {
                    _selectedFilter = value;
                  });
                },
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
                child: _buildBody(results),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(List<Business> results) {
    if (_store.isInitialLoading) {
      return const DirectoryLoadingSkeleton();
    }

    if (_query.trim().isEmpty) {
      return _SearchPrompt(
        businessCount:
            _store.businesses.where((business) => !business.isDeleted).length,
        categoryCount: _store.categories.length,
        onExampleSelected: _selectExample,
      );
    }

    if (_store.isLoading && results.isEmpty) {
      return const DirectoryLoadingSkeleton();
    }

    if (results.isEmpty) {
      return _EmptySearchResults(
        query: _query,
        onClear: _clearSearch,
      );
    }

    return RefreshIndicator(
      onRefresh: _store.refresh,
      child: CustomScrollView(
        key: const PageStorageKey<String>('directory-search-results'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: DirectoryResultSummary(
              count: results.length,
              label: 'نتائج البحث',
              icon: Icons.fact_check_outlined,
              summaryKey: 'directory-search-result-count',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              120,
            ),
            sliver: SliverList.separated(
              itemCount: results.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final business = results[index];

                return BusinessCard(
                  key: ValueKey<String>('search-result-${business.id}'),
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
      'featured' => business.isFeatured,
      'transport' => _belongsToGroup(
          business,
          CategoryDisplayGroup.transport,
        ),
      'services' => !_belongsToGroup(
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

  static int _compareBusinesses(Business first, Business second) {
    if (first.isFeatured != second.isFeatured) {
      return first.isFeatured ? -1 : 1;
    }

    return first.displayName.compareTo(second.displayName);
  }

  void _search(String value) {
    setState(() {
      _query = value;
    });
  }

  void _clearSearch() {
    _controller.clear();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _query = '';
      _selectedFilter = 'all';
    });
  }

  void _selectExample(String example) {
    _controller.text = example;
    _controller.selection = TextSelection.collapsed(
      offset: example.length,
    );
    _search(example);
  }

  void _openBusiness(Business business) {
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

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt({
    required this.businessCount,
    required this.categoryCount,
    required this.onExampleSelected,
  });

  final int businessCount;
  final int categoryCount;
  final ValueChanged<String> onExampleSelected;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    const examples = ['مطاعم', 'صيدليات', 'ورش', 'نقل'];

    return ListView(
      key: const ValueKey<String>('search-prompt'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        120,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                AppColors.primarySoft,
                AppColors.mintSoft,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.travel_explore_rounded,
                size: 48,
                color: AppColors.primaryTeal,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'ما الذي تبحث عنه اليوم؟',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'اكتب اسم النشاط أو الخدمة أو الموقع أو رقم التواصل.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _SearchStatCard(
                icon: Icons.storefront_rounded,
                value: businessCount,
                label: 'نشاط متاح',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SearchStatCard(
                icon: Icons.grid_view_rounded,
                value: categoryCount,
                label: 'قسم وخدمة',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'اقتراحات سريعة',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: examples.map((example) {
            return ActionChip(
              key: ValueKey<String>('search-example-$example'),
              onPressed: () => onExampleSelected(example),
              avatar: const Icon(
                Icons.search_rounded,
                size: 17,
              ),
              label: Text(example),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}

class _SearchStatCard extends StatelessWidget {
  const _SearchStatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primaryTeal,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: AppTextStyles.titleMedium,
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySearchResults extends StatelessWidget {
  const _EmptySearchResults({
    required this.query,
    required this.onClear,
  });

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return RefreshIndicator(
      onRefresh: DirectoryDataStore.instance.refresh,
      child: ListView(
        key: const ValueKey<String>('empty-search-results'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          42,
          AppSpacing.xl,
          120,
        ),
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 60,
            color: AppColors.primaryTeal,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'لا توجد نتائج لـ «$query»',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'جرّب اسمًا أقصر أو اختر فلترًا مختلفًا.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              label: const Text('مسح البحث والفلاتر'),
            ),
          ),
        ],
      ),
    );
  }
}
