import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/auth_session_store.dart';
import '../../core/services/automatic_sync_coordinator.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../auth/google_sign_in_page.dart';
import '../directory/categories_overview_page.dart';
import '../profile/account_hub_page.dart';
import '../profile/owned_businesses_page.dart';
import '../profile/profile_page.dart';
import '../search/directory_search_page.dart';
import 'home_dashboard_page.dart';

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
        onOpenCategories: _openCategoriesPage,
      ),
      _MyActivitiesTab(
        authStore: _authStore,
        onSignIn: _openSignIn,
      ),
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

  Future<void> _openCategoriesPage() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const CategoriesOverviewPage(),
      ),
    );
  }

  Future<void> _openSignIn() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const GoogleSignInPage(),
      ),
    );
  }

  Future<void> _openAddBusinessFlow() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => _authStore.isAuthenticated
            ? const ProfilePage(startInCreateMode: true)
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
    AppColors.bindToTheme(context);
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      resizeToAvoidBottomInset: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _AdaptiveBottomNavigationBar(
        selectedIndex: _currentIndex,
        onSelected: _selectTab,
        onBusinessAction: _openAddBusinessFlow,
        showBusinessAction: !isKeyboardVisible,
      ),
    );
  }
}

class _AdaptiveBottomNavigationBar extends StatelessWidget {
  const _AdaptiveBottomNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.onBusinessAction,
    required this.showBusinessAction,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onBusinessAction;
  final bool showBusinessAction;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final mediaQuery = MediaQuery.of(context);
    final requestedScale = mediaQuery.textScaler.scale(1);
    final navigationTextScale = requestedScale.clamp(1.0, 1.08).toDouble();

    return Material(
      key: const ValueKey<String>('main-navigation-bar'),
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: AppShadows.navigation,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(navigationTextScale),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: AppSizes.bottomBarHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _NavigationDestinationButton(
                      keyName: 'nav-home',
                      label: 'الرئيسية',
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      selected: selectedIndex == 0,
                      onTap: () => onSelected(0),
                    ),
                  ),
                  Expanded(
                    child: _NavigationDestinationButton(
                      keyName: 'nav-search',
                      label: 'بحث',
                      icon: Icons.search_outlined,
                      selectedIcon: Icons.search_rounded,
                      selected: selectedIndex == 2,
                      onTap: () => onSelected(2),
                    ),
                  ),
                  Expanded(
                    child: showBusinessAction
                        ? _BusinessActionButton(
                            onTap: onBusinessAction,
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: _NavigationDestinationButton(
                      keyName: 'nav-categories',
                      label: 'أنشطتي',
                      icon: Icons.assignment_outlined,
                      selectedIcon: Icons.assignment_rounded,
                      selected: selectedIndex == 1,
                      onTap: () => onSelected(1),
                    ),
                  ),
                  Expanded(
                    child: _NavigationDestinationButton(
                      keyName: 'nav-account',
                      label: 'حسابي',
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                      selected: selectedIndex == 3,
                      onTap: () => onSelected(3),
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

class _BusinessActionButton extends StatelessWidget {
  const _BusinessActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Semantics(
      button: true,
      label: 'إضافة نشاط',
      child: InkWell(
        key: const ValueKey<String>('business-action-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, -10),
              child: Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppColors.lightTeal,
                      AppColors.primaryTeal,
                      AppColors.primaryDark,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.floating,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.white,
                  size: 34,
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -8),
              child: Text(
                'إضافة نشاط',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationDestinationButton extends StatelessWidget {
  const _NavigationDestinationButton({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String keyName;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final foregroundColor =
        selected ? AppColors.primaryTeal : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          key: ValueKey<String>(keyName),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: selected ? 26 : 24,
                  color: foregroundColor,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: foregroundColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    height: 1.05,
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

class _MyActivitiesTab extends StatelessWidget {
  const _MyActivitiesTab({
    required this.authStore,
    required this.onSignIn,
  });

  final AuthSessionStore authStore;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return AnimatedBuilder(
      animation: authStore,
      builder: (context, child) {
        if (authStore.isAuthenticated) {
          return const OwnedBusinessesPage();
        }

        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(title: const Text('أنشطتي')),
          body: Center(
            child: Container(
              key: const ValueKey<String>(
                'my-activities-sign-in-prompt',
              ),
              margin: const EdgeInsets.all(AppSpacing.lg),
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.outline),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.primaryTeal,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'سجّل الدخول لإدارة أنشطتك',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'أضف أكثر من نشاط وتابع حالته وعمليات مزامنته.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: onSignIn,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('تسجيل الدخول'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
