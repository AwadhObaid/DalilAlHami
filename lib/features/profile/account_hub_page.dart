import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/auth_session_store.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../../data/repositories/account_repository.dart';
import '../../models/account_profile.dart';
import '../admin/admin_dashboard_page.dart';
import '../admin/widgets/admin_dashboard_entry_card.dart';
import '../auth/google_sign_in_page.dart';
import '../shared/widgets/page_header.dart';
import '../settings/app_settings_page.dart';
import 'account_profile_page.dart';
import 'background_sync_settings_page.dart';
import 'contact_admin_page.dart';
import 'favorite_businesses_page.dart';
import 'owned_businesses_page.dart';
import 'profile_page.dart';
import 'sync_queue_page.dart';
import 'widgets/add_business_button.dart';

class AccountHubPage extends StatefulWidget {
  const AccountHubPage({
    this.refreshSignal = 0,
    super.key,
  });

  final int refreshSignal;

  @override
  State<AccountHubPage> createState() => _AccountHubPageState();
}

class _AccountHubPageState extends State<AccountHubPage>
    with AutomaticKeepAliveClientMixin<AccountHubPage> {
  final AuthSessionStore _authStore = AuthSessionStore.instance;
  final DirectoryDataStore _directoryStore = DirectoryDataStore.instance;
  final AccountRepository _accountRepository = AccountRepository();

  bool _isSigningOut = false;
  bool _isCheckingOwnedBusiness = false;
  String? _activeUserId;
  String? _ownedBusinessRequestUserId;
  int? _ownedBusinessCount;
  AccountProfile? _accountProfile;
  String? _accountAccessMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _activeUserId = _authStore.user?.id;
    _authStore.addListener(_handleChanged);
    _directoryStore.addListener(_handleChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshOwnedBusinessState();
    });
  }

  @override
  void didUpdateWidget(covariant AccountHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _accountProfile = _authStore.accountProfile ?? _accountProfile;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refreshOwnedBusinessState();
        }
      });
    }
  }

  @override
  void dispose() {
    _authStore.removeListener(_handleChanged);
    _directoryStore.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    if (!mounted) {
      return;
    }

    final currentUserId = _authStore.user?.id;

    if (_activeUserId != currentUserId) {
      _activeUserId = currentUserId;

      setState(() {
        _ownedBusinessCount = null;
        _accountProfile = _authStore.accountProfile;
        _accountAccessMessage = null;
        _isCheckingOwnedBusiness = false;
        _ownedBusinessRequestUserId = null;
      });

      if (currentUserId != null) {
        _refreshOwnedBusinessState();
      }
      return;
    }

    if (currentUserId == null) {
      setState(() {
        _ownedBusinessCount = null;
        _accountProfile = null;
        _accountAccessMessage = null;
        _isCheckingOwnedBusiness = false;
        _ownedBusinessRequestUserId = null;
      });
      return;
    }

    final liveProfile = _authStore.accountProfile;
    setState(() {
      if (liveProfile != null && liveProfile.id == currentUserId) {
        _accountProfile = liveProfile;
        if (!liveProfile.canUseAccount) {
          _ownedBusinessCount = 0;
          _accountAccessMessage = liveProfile.isDeleted
              ? 'تم حذف هذا الحساب ظاهريًا من الإدارة.'
              : 'تم إيقاف هذا الحساب من الإدارة.';
        } else {
          _accountAccessMessage = null;
        }
      }
    });

    if (_ownedBusinessCount == null && !_isCheckingOwnedBusiness) {
      _refreshOwnedBusinessState();
    }
  }

  Future<void> _refreshOwnedBusinessState() async {
    final requestedUserId = _authStore.user?.id;
    if (requestedUserId == null) {
      return;
    }

    if (_isCheckingOwnedBusiness &&
        _ownedBusinessRequestUserId == requestedUserId) {
      return;
    }

    if (mounted) {
      setState(() {
        _isCheckingOwnedBusiness = true;
        _ownedBusinessRequestUserId = requestedUserId;
      });
    }

    try {
      final liveProfile = await _authStore.refreshAccountProfile(force: true);

      if (!mounted || _authStore.user?.id != requestedUserId) {
        return;
      }

      if (liveProfile != null) {
        if (liveProfile.id != requestedUserId) {
          return;
        }
        if (!liveProfile.canUseAccount) {
          throw AccountSuspendedFailure(liveProfile);
        }
      }

      final snapshot = await _accountRepository.loadCurrentAccount();

      if (!mounted ||
          _authStore.user?.id != requestedUserId ||
          snapshot.profile.id != requestedUserId) {
        return;
      }

      setState(() {
        _ownedBusinessCount = snapshot.allBusinesses.length;
        _accountProfile = snapshot.profile;
        _accountAccessMessage = null;
      });
    } on AccountSuspendedFailure catch (error) {
      if (!mounted ||
          _authStore.user?.id != requestedUserId ||
          error.profile.id != requestedUserId) {
        return;
      }

      setState(() {
        _ownedBusinessCount = 0;
        _accountProfile = error.profile;
        _accountAccessMessage = error.message;
      });
    } catch (_) {
      if (!mounted || _authStore.user?.id != requestedUserId) {
        return;
      }

      setState(() {
        _ownedBusinessCount = null;
        _accountProfile = null;
        _accountAccessMessage = null;
      });
    } finally {
      if (mounted && _ownedBusinessRequestUserId == requestedUserId) {
        setState(() {
          _isCheckingOwnedBusiness = false;
          _ownedBusinessRequestUserId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    super.build(context);

    return Column(
      children: [
        PageHeader(
          title: 'حسابي',
          subtitle: _authStore.isAuthenticated
              ? 'إدارة الحساب والنشاط التجاري'
              : 'سجّل الدخول لإضافة نشاطك وإدارته',
          icon: Icons.person_rounded,
        ),
        if (_directoryStore.isRefreshing)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _authStore.isAuthenticated
              ? _buildAuthenticatedView()
              : _buildSignedOutView(),
        ),
      ],
    );
  }

  Widget _buildSignedOutView() {
    final supabaseReady = SupabaseService.isInitialized;

    return ListView(
      key: const PageStorageKey<String>('signed-out-account'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        130,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
            boxShadow: AppShadows.subtle,
          ),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_business_rounded,
                  size: 44,
                  color: AppColors.primaryTeal,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'أضف نشاطك إلى دليل الحامي',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'سجّل باستخدام Google، ثم أرسل بيانات نشاطك '
                'للمراجعة والاعتماد.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: supabaseReady ? _openGoogleSignIn : null,
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('المتابعة باستخدام Google'),
                ),
              ),
              if (!supabaseReady) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'إعداد Supabase غير متاح في نسخة التشغيل الحالية.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildBenefitsCard(),
        const SizedBox(height: AppSpacing.md),
        _AccountActionCard(
          icon: Icons.favorite_rounded,
          title: 'المفضلة',
          subtitle: 'الأنشطة التي حفظتها للعودة إليها بسرعة',
          color: AppColors.danger,
          onTap: _openFavorites,
        ),
        const SizedBox(height: AppSpacing.md),
        _AccountActionCard(
          icon: Icons.settings_rounded,
          title: 'إعدادات التطبيق',
          subtitle: 'حجم الخط والإشعارات واللغة',
          color: AppColors.primaryTeal,
          onTap: _openAppSettings,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AccountActionCard(
          icon: Icons.support_agent_rounded,
          title: AppLocaleText.pick(
            context,
            ar: 'التواصل مع الإدارة',
            en: 'Contact administration',
          ),
          subtitle: AppLocaleText.pick(
            context,
            ar: 'استفسار أو اقتراح أو بلاغ عبر واتساب',
            en: 'Inquiry, suggestion, or report via WhatsApp',
          ),
          color: AppColors.whatsapp,
          onTap: _openContactAdmin,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildConnectionCard(),
      ],
    );
  }

  Widget _buildAuthenticatedView() {
    final user = _authStore.user;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final displayName = _firstNonEmpty([
      metadata['full_name']?.toString(),
      metadata['name']?.toString(),
      user?.email?.split('@').first,
      'مستخدم دليل الحامي',
    ]);
    final email = user?.email ?? 'حساب Google متصل';
    final trimmedName = displayName.trim();
    final firstLetter = trimmedName.isEmpty ? 'م' : trimmedName.substring(0, 1);
    final accountSuspended =
        _accountProfile != null && !_accountProfile!.canUseAccount;

    return ListView(
      key: const PageStorageKey<String>('authenticated-account'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        130,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 31,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  firstLetter,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.primaryTeal,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.verified_user_outlined,
                color: AppColors.success,
              ),
            ],
          ),
        ),
        if (_accountAccessMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          _AccountAccessBanner(message: _accountAccessMessage!),
        ],
        if (_accountProfile?.isAdmin == true && !accountSuspended) ...[
          const SizedBox(height: AppSpacing.md),
          AdminDashboardEntryCard(
            onTap: () {
              _openAdminDashboard();
            },
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _AccountActionCard(
          icon: Icons.account_circle_outlined,
          title: 'بيانات الحساب',
          subtitle: 'الاسم والصورة الشخصية وبيانات التواصل',
          color: AppColors.primaryTeal,
          onTap: accountSuspended ? null : _openAccountProfile,
        ),
        const SizedBox(height: AppSpacing.md),
        AddBusinessButton(
          buttonKey: const ValueKey<String>(
            'account-add-business-button',
          ),
          onPressed: _isCheckingOwnedBusiness || accountSuspended
              ? null
              : _openCreateBusiness,
          label: accountSuspended
              ? 'الحساب موقوف'
              : _isCheckingOwnedBusiness
                  ? 'جارٍ التحقق من الأنشطة'
                  : 'إضافة نشاط جديد',
        ),
        const SizedBox(height: AppSpacing.sm),
        _AccountActionCard(
          icon: Icons.storefront_rounded,
          title: 'إدارة أنشطتي',
          subtitle: _ownedBusinessCount == null
              ? 'عرض الأنشطة المسجلة وإدارتها'
              : _ownedBusinessCount == 0
                  ? 'لا توجد أنشطة مسجلة حتى الآن'
                  : 'إدارة $_ownedBusinessCount نشاط ومتابعة حالاتها',
          color: AppColors.primaryTeal,
          onTap: accountSuspended ? null : _openProfile,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AccountActionCard(
          icon: Icons.cloud_sync_rounded,
          title: 'عمليات المزامنة',
          subtitle: _directoryStore.pendingSyncOperationCount > 0
              ? 'توجد ${_directoryStore.pendingSyncOperationCount} عملية بانتظار الإرسال'
              : _directoryStore.failedSyncOperationCount > 0
                  ? 'توجد عمليات تحتاج إعادة المحاولة'
                  : 'عرض العمليات المحلية وحالة إرسالها',
          color: AppColors.warning,
          onTap: accountSuspended ? null : _openSyncQueue,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AccountActionCard(
          icon: Icons.settings_backup_restore_rounded,
          title: 'المزامنة في الخلفية',
          subtitle: 'الجدولة والإشعارات وحالة آخر تشغيل',
          color: AppColors.lightTeal,
          onTap: accountSuspended ? null : _openBackgroundSyncSettings,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AccountActionCard(
          icon: Icons.sync_rounded,
          title: 'تحديث بيانات الدليل',
          subtitle: 'جلب أحدث الأقسام والأنشطة من Supabase',
          color: AppColors.lightTeal,
          onTap: accountSuspended || _directoryStore.isLoading
              ? null
              : _directoryStore.refresh,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AccountActionCard(
          icon: Icons.favorite_rounded,
          title: 'المفضلة',
          subtitle: 'عرض الأنشطة المحفوظة ومزامنتها مع الحساب',
          color: AppColors.danger,
          onTap: _openFavorites,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AccountActionCard(
          icon: Icons.settings_rounded,
          title: 'إعدادات التطبيق',
          subtitle: 'حجم الخط والإشعارات واللغة',
          color: AppColors.primaryTeal,
          onTap: _openAppSettings,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AccountActionCard(
          icon: Icons.support_agent_rounded,
          title: AppLocaleText.pick(
            context,
            ar: 'التواصل مع الإدارة',
            en: 'Contact administration',
          ),
          subtitle: AppLocaleText.pick(
            context,
            ar: 'استفسار أو اقتراح أو بلاغ عبر واتساب',
            en: 'Inquiry, suggestion, or report via WhatsApp',
          ),
          color: AppColors.whatsapp,
          onTap: _openContactAdmin,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildConnectionCard(),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _isSigningOut ? null : _confirmSignOut,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ),
          icon: _isSigningOut
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: const Text('تسجيل الخروج'),
        ),
      ],
    );
  }

  Widget _buildBenefitsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: const Column(
        children: [
          _BenefitRow(
            icon: Icons.person_outline_rounded,
            text: 'كل مستخدم يدير أنشطته فقط',
          ),
          Divider(),
          _BenefitRow(
            icon: Icons.fact_check_outlined,
            text: 'النشاط يظهر بعد مراجعة الإدارة',
          ),
          Divider(),
          _BenefitRow(
            icon: Icons.lock_outline_rounded,
            text: 'البيانات محمية بصلاحيات Supabase',
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    final isOnline = _directoryStore.usesSupabase;
    final usesSqlite = _directoryStore.usesSqliteCache;
    final title = _directoryStore.isRefreshing
        ? 'جارٍ مزامنة بيانات الدليل'
        : _directoryStore.storageStatusTitle;
    final subtitle = _directoryStore.storageStatusSubtitle;
    final color = isOnline
        ? AppColors.success
        : usesSqlite
            ? AppColors.primaryTeal
            : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _directoryStore.isRefreshing
                ? Icons.sync_rounded
                : isOnline
                    ? Icons.cloud_done_outlined
                    : usesSqlite
                        ? Icons.storage_rounded
                        : Icons.cloud_off_outlined,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: color,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGoogleSignIn() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const GoogleSignInPage(),
      ),
    );

    if (mounted) {
      setState(() {});
      await _refreshOwnedBusinessState();
    }
  }

  Future<void> _openAccountProfile() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const AccountProfilePage(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _refreshOwnedBusinessState();
  }

  Future<void> _openCreateBusiness() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const ProfilePage(
          startInCreateMode: true,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _refreshOwnedBusinessState();
    await _directoryStore.refresh();
  }

  Future<void> _openProfile() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const OwnedBusinessesPage(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _refreshOwnedBusinessState();
    await _directoryStore.refresh();
  }

  Future<void> _openFavorites() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const FavoriteBusinessesPage(),
      ),
    );
  }

  Future<void> _openAppSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const AppSettingsPage(),
      ),
    );
  }

  Future<void> _openContactAdmin() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const ContactAdminPage(),
      ),
    );
  }

  Future<void> _openAdminDashboard() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const AdminDashboardPage(),
      ),
    );

    if (mounted) {
      await _refreshOwnedBusinessState();
    }
  }

  Future<void> _openSyncQueue() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const SyncQueuePage(),
      ),
    );

    await _directoryStore.refreshSyncQueueState();
  }

  Future<void> _openBackgroundSyncSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const BackgroundSyncSettingsPage(),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text(
            'هل تريد تسجيل الخروج من هذا الجهاز؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    try {
      await _authStore.signOut();
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return AppLocaleText.runtime('مستخدم دليل الحامي');
  }
}

class _AccountAccessBanner extends StatelessWidget {
  const _AccountAccessBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      key: const ValueKey<String>('account-suspended-banner'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.block_rounded,
            color: AppColors.danger,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الحساب موقوف',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  message,
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

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryTeal),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _AccountActionCard extends StatelessWidget {
  const _AccountActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                onTap!();
              },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
