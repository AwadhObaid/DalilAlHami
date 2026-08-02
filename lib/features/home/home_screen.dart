import 'package:flutter/material.dart';

import '../../core/constants/app_catalog.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/launch_actions.dart';
import '../../data/local_directory_store.dart';
import '../../models/business.dart';
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
  final LocalDirectoryStore _store = LocalDirectoryStore.instance;
  final TextEditingController _searchController = TextEditingController();
  final PageController _adPageController = PageController();

  String _searchQuery = '';
  List<Business> _foundBusinesses = const [];

  @override
  void initState() {
    super.initState();
    _store.addListener(_handleStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_handleStoreChanged);
    _searchController.dispose();
    _adPageController.dispose();
    super.dispose();
  }

  void _handleStoreChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _foundBusinesses = _store.search(_searchQuery);
    });
  }

  void _runFilter(String enteredKeyword) {
    setState(() {
      _searchQuery = enteredKeyword;
      _foundBusinesses = _store.search(enteredKeyword);
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
          Expanded(
            child: _searchQuery.isNotEmpty
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
          _store.isSubscribed ? Icons.person : Icons.add,
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

  Future<void> _openAccountPage() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            _store.isSubscribed ? const ProfilePage() : const PhoneEntryPage(),
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
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: AppCatalog.transport.length,
        itemBuilder: (context, index) {
          final category = AppCatalog.transport[index];

          return CategoryCircleItem(
            category: category,
            onTap: () => _openCategory(category.name),
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
    return GridView.builder(
      padding: const EdgeInsets.all(15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: AppCatalog.services.length,
      itemBuilder: (context, index) {
        final category = AppCatalog.services[index];

        return InkWell(
          onTap: () => _openCategory(category.name),
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

  void _openCategory(String categoryName) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => CategoryListPage(
          categoryName: categoryName,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
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
    );
  }
}
