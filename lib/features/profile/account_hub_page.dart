import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/auth_session_store.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../auth/google_sign_in_page.dart';
import '../shared/widgets/page_header.dart';
import 'profile_page.dart';

class AccountHubPage extends StatefulWidget {
  const AccountHubPage({super.key});

  @override
  State<AccountHubPage> createState() => _AccountHubPageState();
}

class _AccountHubPageState extends State<AccountHubPage>
    with AutomaticKeepAliveClientMixin<AccountHubPage> {
  final AuthSessionStore _authStore = AuthSessionStore.instance;
  final DirectoryDataStore _directoryStore = DirectoryDataStore.instance;

  bool _isSigningOut = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _authStore.addListener(_handleChanged);
    _directoryStore.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _authStore.removeListener(_handleChanged);
    _directoryStore.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
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
                decoration: const BoxDecoration(
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
        const SizedBox(height: AppSpacing.md),
        _AccountActionCard(
          icon: Icons.storefront_rounded,
          title: 'إدارة نشاطي',
          subtitle: 'إضافة النشاط أو تعديل بياناته ومتابعة حالة المراجعة',
          color: AppColors.primaryTeal,
          onTap: _openProfile,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AccountActionCard(
          icon: Icons.sync_rounded,
          title: 'تحديث بيانات الدليل',
          subtitle: 'جلب أحدث الأقسام والأنشطة من Supabase',
          color: AppColors.lightTeal,
          onTap: _directoryStore.isLoading ? null : _directoryStore.refresh,
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
            text: 'كل مستخدم يدير نشاطه فقط',
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
    }
  }

  Future<void> _openProfile() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const ProfilePage(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _directoryStore.refresh();
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

    return 'مستخدم دليل الحامي';
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
              const Icon(
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
