import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/auth_session_store.dart';
import '../../core/services/favorite_store.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../directory/member_details_page.dart';
import '../directory/widgets/business_card.dart';

class FavoriteBusinessesPage extends StatefulWidget {
  const FavoriteBusinessesPage({super.key});

  @override
  State<FavoriteBusinessesPage> createState() => _FavoriteBusinessesPageState();
}

class _FavoriteBusinessesPageState extends State<FavoriteBusinessesPage> {
  final FavoriteStore _favoriteStore = FavoriteStore.instance;
  final DirectoryDataStore _directoryStore = DirectoryDataStore.instance;
  final AuthSessionStore _authStore = AuthSessionStore.instance;

  @override
  void initState() {
    super.initState();
    _favoriteStore.addListener(_handleChanged);
    _directoryStore.addListener(_handleChanged);
    _authStore.addListener(_handleChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_directoryStore.hasLoaded) {
        _directoryStore.load();
      }
      if (_authStore.isAuthenticated && SupabaseService.isInitialized) {
        _favoriteStore.syncWithRemote();
      }
    });
  }

  @override
  void dispose() {
    _favoriteStore.removeListener(_handleChanged);
    _directoryStore.removeListener(_handleChanged);
    _authStore.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      _directoryStore.refresh(),
      _favoriteStore.syncWithRemote(),
    ]);
  }

  Future<void> _openBusiness(int index) async {
    final businesses =
        _favoriteStore.favoriteBusinesses(_directoryStore.businesses);
    if (index < 0 || index >= businesses.length) {
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => MemberDetailsPage(business: businesses[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final businesses =
        _favoriteStore.favoriteBusinesses(_directoryStore.businesses);
    final remoteReady =
        _authStore.isAuthenticated && SupabaseService.isInitialized;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('المفضلة'),
      ),
      body: Column(
        children: [
          if (_favoriteStore.isSyncing || _directoryStore.isRefreshing)
            const LinearProgressIndicator(minHeight: 2),
          if (_favoriteStore.lastError != null)
            _FavoriteStatusBanner(
              message: AppLocaleText.pick(
                context,
                ar: 'تعذر مزامنة المفضلة مؤقتًا؛ التغييرات محفوظة على هذا الجهاز.',
                en: 'Favorites could not sync right now; changes are saved on this device.',
              ),
              color: AppColors.warning,
            )
          else if (!remoteReady)
            _FavoriteStatusBanner(
              message: AppLocaleText.pick(
                context,
                ar: 'المفضلة محفوظة على هذا الجهاز. عند تسجيل الدخول ستتم مزامنتها مع حسابك.',
                en: 'Favorites are saved on this device. Sign in to sync them with your account.',
              ),
              color: AppColors.primaryTeal,
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: businesses.isEmpty
                  ? ListView(
                      key: const ValueKey<String>('favorites-empty-list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        96,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 72,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'لا توجد أنشطة في المفضلة',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'اضغط على رمز القلب في أي نشاط ليظهر هنا.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      key: const ValueKey<String>('favorites-business-list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.xxl,
                      ),
                      itemCount: businesses.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final business = businesses[index];
                        return BusinessCard(
                          business: business,
                          onOpen: () => _openBusiness(index),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteStatusBanner extends StatelessWidget {
  const _FavoriteStatusBanner({
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: color.withValues(alpha: 0.10),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall.copyWith(color: color),
      ),
    );
  }
}
