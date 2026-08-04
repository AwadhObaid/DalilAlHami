import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/auth_session_store.dart';
import '../../core/services/automatic_sync_coordinator.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../auth/google_sign_in_page.dart';
import '../directory/categories_overview_page.dart';
import '../profile/account_hub_page.dart';
import '../profile/profile_page.dart';
import '../search/directory_search_page.dart';
import 'home_dashboard_page.dart';
import 'widgets/automatic_sync_status_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    this.initialIndex = 0,
    super.key,
  });

  final int initialIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthSessionStore _authStore = AuthSessionStore.instance;
  final DirectoryDataStore _directoryStore = DirectoryDataStore.instance;
  final AutomaticSyncCoordinator _syncCoordinator =
      AutomaticSyncCoordinator.instance;

  late int _currentIndex;
  late final List<Widget> _pages;
  int _lastAnnouncedSyncEvent = 0;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex < 0
        ? 0
        : widget.initialIndex > 3
            ? 3
            : widget.initialIndex;
    _pages = [
      HomeDashboardPage(
        onOpenSearch: () => _selectTab(2),
        onOpenCategories: () => _selectTab(1),
      ),
      const CategoriesOverviewPage(),
      const DirectorySearchPage(),
      const AccountHubPage(),
    ];

    _authStore.addListener(_handleAuthChanged);
    _syncCoordinator.addListener(_handleAutomaticSyncChanged);

    if (!_directoryStore.hasLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _directoryStore.load();
      });
    }
  }

  @override
  void dispose() {
    _authStore.removeListener(_handleAuthChanged);
    _syncCoordinator.removeListener(_handleAutomaticSyncChanged);
    super.dispose();
  }

  void _handleAuthChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleAutomaticSyncChanged() {
    if (!mounted) {
      return;
    }

    final snapshot = _syncCoordinator.snapshot;
    setState(() {});

    if (!snapshot.announce || snapshot.eventId == _lastAnnouncedSyncEvent) {
      return;
    }

    _lastAnnouncedSyncEvent = snapshot.eventId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final isAttention =
          snapshot.phase == AutomaticSyncPhase.attentionRequired;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snapshot.message),
          backgroundColor: isAttention ? AppColors.danger : AppColors.success,
        ),
      );
    });
  }

  void _selectTab(int index) {
    if (_currentIndex == index) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _openAccountFlow() async {
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

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: <Widget>[
          AutomaticSyncStatusBanner(
            coordinator: _syncCoordinator,
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      floatingActionButton: isKeyboardVisible
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey<String>(
                'business-action-button',
              ),
              onPressed: _openAccountFlow,
              icon: Icon(
                _authStore.isAuthenticated
                    ? Icons.storefront_rounded
                    : Icons.add_business_rounded,
              ),
              label: Text(
                _authStore.isAuthenticated ? 'نشاطي' : 'أضف نشاطك',
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _AdaptiveBottomNavigationBar(
        selectedIndex: _currentIndex,
        onSelected: _selectTab,
      ),
    );
  }
}

class _AdaptiveBottomNavigationBar extends StatelessWidget {
  const _AdaptiveBottomNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final requestedScale = mediaQuery.textScaler.scale(1);
    final navigationTextScale = requestedScale.clamp(1.0, 1.1);

    const destinations = [
      _NavigationDestinationData(
        keyName: 'nav-home',
        label: 'الرئيسية',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      _NavigationDestinationData(
        keyName: 'nav-categories',
        label: 'الأقسام',
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view_rounded,
      ),
      _NavigationDestinationData(
        keyName: 'nav-search',
        label: 'البحث',
        icon: Icons.search_outlined,
        selectedIcon: Icons.search_rounded,
      ),
      _NavigationDestinationData(
        keyName: 'nav-account',
        label: 'حسابي',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];

    return Material(
      key: const ValueKey<String>('main-navigation-bar'),
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      child: MediaQuery(
        data: mediaQuery.copyWith(
          textScaler: TextScaler.linear(navigationTextScale),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              6,
              AppSpacing.xs,
              6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(destinations.length, (index) {
                final destination = destinations[index];

                return Expanded(
                  child: _NavigationDestinationButton(
                    data: destination,
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationDestinationButton extends StatelessWidget {
  const _NavigationDestinationButton({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavigationDestinationData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor =
        selected ? AppColors.primaryTeal : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          key: ValueKey<String>(data.keyName),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 62),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? data.selectedIcon : data.icon,
                  size: selected ? 25 : 23,
                  color: foregroundColor,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: foregroundColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    height: 1.1,
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

class _NavigationDestinationData {
  const _NavigationDestinationData({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String keyName;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
