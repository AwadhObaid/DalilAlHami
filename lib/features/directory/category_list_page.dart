import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/launch_actions.dart';
import '../../data/directory_data_store.dart';
import '../../models/business.dart';
import '../../models/directory_advertisement.dart';
import '../../models/service_category.dart';
import '../shared/widgets/directory_loading_skeleton.dart';
import '../shared/widgets/directory_page_header.dart';
import '../shared/widgets/directory_result_summary.dart';
import '../shared/widgets/directory_search_field.dart';
import '../shared/widgets/directory_status_banner.dart';
import '../shared/widgets/inline_advertisement_banner.dart';
import 'member_details_page.dart';
import 'widgets/business_card.dart';

class CategoryListPage extends StatefulWidget {
  const CategoryListPage({
    required this.categoryName,
    this.categoryId = '',
    this.categoryIcon = Icons.category_rounded,
    super.key,
  });

  final String categoryName;
  final String categoryId;
  final IconData categoryIcon;

  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> {
  final DirectoryDataStore _store = DirectoryDataStore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _query = '';

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
      key: const ValueKey<String>('category-list-page-shell'),
      backgroundColor: AppColors.pageBackground,
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, child) {
          final businesses = _filteredBusinesses;

          return Column(
            children: [
              if (!keyboardVisible)
                DirectoryPageHeader(
                  headerKey: 'category-list-header',
                  title: widget.categoryName,
                  subtitle: 'الأنشطة المسجلة ضمن هذا القسم',
                  icon: widget.categoryIcon,
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
                  fieldKey: 'category-list-search-field',
                  hintText: 'ابحث داخل قسم ${widget.categoryName}…',
                ),
              ),
              DirectoryResultSummary(
                count: businesses.length,
                label: 'أنشطة القسم',
                icon: widget.categoryIcon,
                summaryKey: 'category-list-result-count',
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
                child: _buildBody(
                  businesses,
                  _store.advertisementsForPlacement('business_list'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Business> get _filteredBusinesses {
    final category = _resolveCategory(_store);
    final source = category == null
        ? _store.businesses.where(
            (business) => business.category == widget.categoryName,
          )
        : _store.byCategory(category);
    final query = _query.trim();
    final values =
        source.where((business) => !business.isDeleted).where((business) {
      return query.isEmpty || business.matchesSearch(query);
    }).toList(growable: true);

    values.sort(_compareBusinesses);
    return values;
  }

  Widget _buildBody(
    List<Business> businesses,
    List<DirectoryAdvertisement> advertisements,
  ) {
    if (_store.isInitialLoading) {
      return const DirectoryLoadingSkeleton();
    }

    if (businesses.isEmpty) {
      return RefreshIndicator(
        onRefresh: _store.refresh,
        child: _EmptyCategoryState(
          categoryName: widget.categoryName,
          hasSearch: _query.trim().isNotEmpty,
          onClearSearch: _clearSearch,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _store.refresh,
      child: ListView.separated(
        key: const PageStorageKey<String>('category-business-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        itemCount: businesses.length + (advertisements.isNotEmpty ? 1 : 0),
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (advertisements.isNotEmpty && index == 0) {
            return InlineAdvertisementBanner(
              advertisements: advertisements,
              onOpen: _openAdvertisement,
            );
          }

          final businessIndex = index - (advertisements.isNotEmpty ? 1 : 0);
          final business = businesses[businessIndex];

          return BusinessCard(
            key: ValueKey<String>('category-business-${business.id}'),
            business: business,
            onOpen: () => _openBusiness(business),
          );
        },
      ),
    );
  }

  ServiceCategory? _resolveCategory(DirectoryDataStore store) {
    for (final category in store.categories) {
      if (widget.categoryId.isNotEmpty && category.id == widget.categoryId) {
        return category;
      }

      if (category.name == widget.categoryName) {
        return category;
      }
    }

    return null;
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

  static int _compareBusinesses(Business first, Business second) {
    if (first.isFeatured != second.isFeatured) {
      return first.isFeatured ? -1 : 1;
    }

    return first.displayName.compareTo(second.displayName);
  }
}

class _EmptyCategoryState extends StatelessWidget {
  const _EmptyCategoryState({
    required this.categoryName,
    required this.hasSearch,
    required this.onClearSearch,
  });

  final String categoryName;
  final bool hasSearch;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey<String>('empty-category-state'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: 40),
        const Icon(
          Icons.storefront_outlined,
          color: AppColors.primaryTeal,
          size: 58,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          hasSearch ? 'لا توجد نتائج مطابقة' : 'لا توجد أنشطة حاليًا',
          style: AppTextStyles.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          hasSearch
              ? 'لا يوجد نشاط مطابق لبحثك داخل قسم $categoryName.'
              : 'لم تُضف بيانات معتمدة إلى قسم $categoryName بعد.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        if (hasSearch) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: OutlinedButton.icon(
              onPressed: onClearSearch,
              icon: const Icon(Icons.close_rounded),
              label: const Text('مسح البحث'),
            ),
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'اسحب إلى الأسفل لمحاولة تحديث البيانات.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
