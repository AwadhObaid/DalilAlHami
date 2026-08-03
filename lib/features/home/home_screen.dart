import 'package:flutter/material.dart';

import '../../core/constants/app_catalog.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/auth_session_store.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/launch_actions.dart';
import '../../data/directory_data_store.dart';
import '../../models/business.dart';
import '../../models/service_category.dart';
import '../auth/google_sign_in_page.dart';
import '../directory/category_list_page.dart';
import '../directory/member_details_page.dart';
import '../directory/widgets/business_card.dart';
import '../profile/profile_page.dart';
import 'widgets/ad_slider.dart';
import 'widgets/category_circle_item.dart';
import 'widgets/home_header.dart';
import 'widgets/search_box.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DirectoryDataStore _directoryStore = DirectoryDataStore.instance;
  final AuthSessionStore _authStore = AuthSessionStore.instance;
  final TextEditingController _searchController = TextEditingController();
  final PageController _adPageController = PageController();

  String _searchQuery = '';
  List<Business> _foundBusinesses = const [];

  @override
  void initState() {
    super.initState();
    _directoryStore.addListener(_handleDirectoryChanged);
    _authStore.addListener(_handleAuthChanged);

    if (!_directoryStore.hasLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _directoryStore.load();
      });
    }
  }

  @override
  void dispose() {
    _directoryStore.removeListener(_handleDirectoryChanged);
    _authStore.removeListener(_handleAuthChanged);
    _searchController.dispose();
    _adPageController.dispose();
    super.dispose();
  }

  void _handleDirectoryChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _foundBusinesses = _directoryStore.search(_searchQuery);
    });
  }

  void _handleAuthChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _runFilter(String enteredKeyword) {
    setState(() {
      _searchQuery = enteredKeyword;
      _foundBusinesses = _directoryStore.search(enteredKeyword);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _searchQuery = '';
      _foundBusinesses = const [];
    });
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
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          const HomeHeader(),
          SearchBox(
            controller: _searchController,
            query: _searchQuery,
            onChanged: _runFilter,
            onClear: _clearSearch,
          ),
          if (_directoryStore.isLoading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _searchQuery.trim().isNotEmpty
                  ? _buildSearchResults()
                  : _buildMainContent(),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        tooltip:
            _authStore.isAuthenticated ? 'فتح الملف الشخصي' : 'إضافة نشاط جديد',
        shape: const CircleBorder(
          side: BorderSide(
            color: AppColors.white,
            width: 4,
          ),
        ),
        onPressed: _openAccountPage,
        child: Icon(
          _authStore.isAuthenticated
              ? Icons.person_rounded
              : Icons.add_business_rounded,
          size: 31,
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.primaryDark,
        surfaceTintColor: Colors.transparent,
        shape: const CircularNotchedRectangle(),
        notchMargin: AppSpacing.xs,
        elevation: 10,
        child: const SizedBox(height: AppSizes.bottomBarHeight),
      ),
    );
  }

  Future<void> _openAccountPage() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => _authStore.isAuthenticated
            ? const ProfilePage()
            : const GoogleSignInPage(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _directoryStore.refresh();
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _directoryStore.refresh,
      child: ListView(
        key: const ValueKey<String>('home-content'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: 96,
        ),
        children: [
          if (_directoryStore.fallbackMessage != null) _buildDataSourceNotice(),
          AdSlider(
            controller: _adPageController,
            advertisements: AppCatalog.advertisements,
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader(
            title: 'خدمات النقل',
            subtitle: 'وصول أسرع للخدمات اليومية',
            icon: Icons.route_rounded,
          ),
          _buildHorizontalCategories(),
          _buildSuggestionBox(),
          const SizedBox(height: AppSpacing.xs),
          _buildSectionHeader(
            title: 'الخدمات والأنشطة',
            subtitle: 'اختر القسم الذي تبحث عنه',
            icon: Icons.grid_view_rounded,
          ),
          _buildServiceGrid(),
        ],
      ),
    );
  }

  Widget _buildDataSourceNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
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
              _directoryStore.fallbackMessage!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryDark,
              ),
            ),
          ),
          IconButton(
            tooltip: 'إعادة المحاولة',
            onPressed: _directoryStore.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
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
        ],
      ),
    );
  }

  Widget _buildHorizontalCategories() {
    final categories = _transportCategories;

    return SizedBox(
      height: 106,
      child: ListView.separated(
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

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.96,
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

  Widget _buildSearchResults() {
    if (_directoryStore.isLoading && _foundBusinesses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_foundBusinesses.isEmpty) {
      return _buildEmptySearchState();
    }

    return RefreshIndicator(
      onRefresh: _directoryStore.refresh,
      child: ListView.separated(
        key: const ValueKey<String>('search-results'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          96,
        ),
        itemCount: _foundBusinesses.length,
        separatorBuilder: (context, index) => const SizedBox(
          height: AppSpacing.sm,
        ),
        itemBuilder: (context, index) {
          final business = _foundBusinesses[index];

          return BusinessCard(
            business: business,
            onOpen: () => _openBusiness(business),
          );
        },
      ),
    );
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

  Widget _buildEmptySearchState() {
    return RefreshIndicator(
      onRefresh: _directoryStore.refresh,
      child: ListView(
        key: const ValueKey<String>('empty-search'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          72,
          AppSpacing.xl,
          96,
        ),
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 42,
              color: AppColors.primaryTeal,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'لم نجد نشاطًا مطابقًا',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'جرّب كتابة اسم آخر أو ابحث باسم القسم أو رقم الهاتف.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: OutlinedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('مسح البحث'),
            ),
          ),
        ],
      ),
    );
  }
}
