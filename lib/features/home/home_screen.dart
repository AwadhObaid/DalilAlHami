import 'package:flutter/material.dart';

import '../../core/constants/app_catalog.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/launch_actions.dart';
import '../../data/directory_data_store.dart';
import '../../data/local_directory_store.dart';
import '../../models/business.dart';
import '../../models/service_category.dart';
import '../auth/phone_entry_page.dart';
import '../directory/category_list_page.dart';
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
  final LocalDirectoryStore _profileStore = LocalDirectoryStore.instance;
  final TextEditingController _searchController = TextEditingController();
  final PageController _adPageController = PageController();

  String _searchQuery = '';
  List<Business> _foundBusinesses = const [];

  @override
  void initState() {
    super.initState();
    _directoryStore.addListener(_handleStoreChanged);

    if (!_directoryStore.hasLoaded) {
      _directoryStore.load();
    }
  }

  @override
  void dispose() {
    _directoryStore.removeListener(_handleStoreChanged);
    _searchController.dispose();
    _adPageController.dispose();
    super.dispose();
  }

  void _handleStoreChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _foundBusinesses = _directoryStore.search(_searchQuery);
    });
  }

  void _runFilter(String enteredKeyword) {
    setState(() {
      _searchQuery = enteredKeyword;
      _foundBusinesses = _directoryStore.search(enteredKeyword);
    });
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _foundBusinesses = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isInitialLoading =
        _directoryStore.isLoading && !_directoryStore.hasLoaded;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          const HomeHeader(),
          SearchBox(
            controller: _searchController,
            query: _searchQuery,
            onChanged: _runFilter,
            onClear: _clearSearch,
          ),
          if (_directoryStore.usesLocalFallback) _buildFallbackNotice(),
          Expanded(
            child: isInitialLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _searchQuery.isNotEmpty
                    ? _buildSearchResults()
                    : _buildMainContent(),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.lightTeal,
        shape: const CircleBorder(
          side: BorderSide(
            color: Colors.white,
            width: 4,
          ),
        ),
        onPressed: _openAccountPage,
        child: Icon(
          _profileStore.isSubscribed ? Icons.person : Icons.add,
          size: 35,
          color: AppColors.primaryTeal,
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.primaryTeal,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: const SizedBox(height: 50),
      ),
    );
  }

  Widget _buildFallbackNotice() {
    return Material(
      color: Colors.amber.shade100,
      child: InkWell(
        onTap: _directoryStore.isLoading ? null : _directoryStore.refresh,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: Colors.black87,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _directoryStore.fallbackMessage ??
                      'تُعرض البيانات المحلية مؤقتًا.',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              if (_directoryStore.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                const Icon(
                  Icons.refresh,
                  size: 19,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAccountPage() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => _profileStore.isSubscribed
            ? const ProfilePage()
            : const PhoneEntryPage(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        AdSlider(
          controller: _adPageController,
          advertisements: AppCatalog.advertisements,
        ),
        const SizedBox(height: 12),
        _buildHorizontalCategories(),
        _buildSuggestionBox(),
        Expanded(
          child: _buildServiceGrid(),
        ),
      ],
    );
  }

  Widget _buildHorizontalCategories() {
    final categories = _directoryStore.transportCategories;

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: categories.length,
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
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 8,
      ),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Text(
              'شكراً لأختيارك دليل الحامي - التطبيق الأفضل',
              style: TextStyle(
                color: AppColors.primaryTeal,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            InkWell(
              onTap: () {
                LaunchActions.openWhatsApp(
                  context,
                  '772551846',
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'لأي اقتراح اضغط هنا',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceGrid() {
    final categories = _directoryStore.serviceCategories;

    return GridView.builder(
      padding: const EdgeInsets.all(15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];

        return InkWell(
          onTap: () => _openCategory(category),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  category.icon,
                  color: AppColors.lightTeal,
                  size: 30,
                ),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
          category: category,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_foundBusinesses.isEmpty) {
      return const Center(
        child: Text(
          'لم يتم العثور على نتائج مطابقة.',
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _directoryStore.refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _foundBusinesses.length,
        itemBuilder: (context, index) {
          final business = _foundBusinesses[index];

          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 5,
            ),
            child: ListTile(
              title: Text(business.name),
              subtitle: Text(business.category),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chat,
                      color: Colors.green,
                    ),
                    onPressed: () {
                      LaunchActions.openWhatsApp(
                        context,
                        business.whatsapp.isNotEmpty
                            ? business.whatsapp
                            : business.phone,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.phone,
                      color: AppColors.primaryTeal,
                    ),
                    onPressed: () {
                      LaunchActions.makePhoneCall(
                        context,
                        business.phone,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
