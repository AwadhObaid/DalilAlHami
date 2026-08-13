import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/admin_repository.dart';
import '../../models/account_profile.dart';
import '../../models/admin_dashboard_snapshot.dart';
import 'admin_advertisement_management_page.dart';
import 'admin_business_management_page.dart';
import 'admin_business_review_page.dart';
import 'admin_category_management_page.dart';
import 'admin_media_management_page.dart';
import 'admin_system_usage_page.dart';
import 'admin_notification_management_page.dart';
import 'admin_user_management_page.dart';

typedef AdminProfileLoader = Future<AccountProfile> Function();
typedef AdminDashboardLoader = Future<AdminDashboardSnapshot> Function();

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    this.profileLoader,
    this.dashboardLoader,
  });

  final AdminProfileLoader? profileLoader;
  final AdminDashboardLoader? dashboardLoader;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

enum _AdminDashboardState {
  loading,
  ready,
  denied,
  failed,
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final AdminRepository _repository = AdminRepository();

  _AdminDashboardState _state = _AdminDashboardState.loading;
  AccountProfile? _profile;
  AdminDashboardSnapshot? _snapshot;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _state = _AdminDashboardState.loading;
        _message = null;
      });
    }

    try {
      final profile = await (widget.profileLoader?.call() ??
          _repository.loadCurrentAdminProfile());

      if (!profile.isActive || !profile.isAdmin) {
        throw const AdminAccessDenied(
          'هذا الحساب لا يملك صلاحية فتح لوحة الإدارة.',
        );
      }

      final snapshot =
          await (widget.dashboardLoader?.call() ?? _repository.loadDashboard());

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _snapshot = snapshot;
        _state = _AdminDashboardState.ready;
      });
    } on AdminAccessDenied catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.message;
        _state = _AdminDashboardState.denied;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = _friendlyMessage(error);
        _state = _AdminDashboardState.failed;
      });
    }
  }

  String _friendlyMessage(Object error) {
    if (error is AdminRepositoryFailure) {
      return error.message;
    }
    return AppLocaleText.runtime(
        'تعذر تحميل بيانات الإدارة. تحقق من الاتصال ثم أعد المحاولة.');
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('لوحة تحكم الإدارة'),
      ),
      body: switch (_state) {
        _AdminDashboardState.loading => const _AdminLoadingView(),
        _AdminDashboardState.denied => _AdminStateView(
            key: const ValueKey<String>('admin-access-denied'),
            icon: Icons.lock_person_rounded,
            title: 'غير مصرح بالدخول',
            message: _message ?? 'لا تملك صلاحية الإدارة.',
            color: AppColors.danger,
            actionLabel: 'العودة',
            onAction: () {
              Navigator.maybePop(context);
            },
          ),
        _AdminDashboardState.failed => _AdminStateView(
            key: const ValueKey<String>('admin-dashboard-error'),
            icon: Icons.cloud_off_rounded,
            title: 'تعذر تحميل لوحة الإدارة',
            message: _message ?? 'تحقق من الاتصال ثم أعد المحاولة.',
            color: AppColors.warning,
            actionLabel: 'إعادة المحاولة',
            onAction: () {
              _loadDashboard();
            },
          ),
        _AdminDashboardState.ready => _buildDashboard(),
      },
    );
  }

  Widget _buildDashboard() {
    final profile = _profile!;
    final snapshot = _snapshot!;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        key: const PageStorageKey<String>('admin-dashboard-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          _AdminWelcomeCard(profile: profile),
          const SizedBox(height: AppSpacing.lg),
          const _SectionTitle(
            title: 'ملخص النظام',
            subtitle: 'قراءة مباشرة ومحمية من Supabase',
          ),
          const SizedBox(height: AppSpacing.sm),
          _ResponsiveMetrics(
            children: [
              _AdminMetricCard(
                key: const ValueKey<String>('admin-users-metric'),
                icon: Icons.people_alt_rounded,
                title: 'المستخدمون',
                value: snapshot.totalUsers,
                detail: '${snapshot.activeUsers} حساب نشط',
                color: AppColors.primaryTeal,
              ),
              _AdminMetricCard(
                key: const ValueKey<String>('admin-businesses-metric'),
                icon: Icons.storefront_rounded,
                title: 'الأنشطة',
                value: snapshot.totalBusinesses,
                detail: '${snapshot.pendingBusinesses} بانتظار المراجعة',
                color: AppColors.warning,
              ),
              _AdminMetricCard(
                key: const ValueKey<String>('admin-categories-metric'),
                icon: Icons.category_rounded,
                title: 'الأقسام',
                value: snapshot.totalCategories,
                detail: '${snapshot.activeCategories} قسم نشط',
                color: AppColors.lightTeal,
              ),
              _AdminMetricCard(
                key: const ValueKey<String>('admin-advertisements-metric'),
                icon: Icons.campaign_rounded,
                title: 'الإعلانات',
                value: snapshot.totalAdvertisements,
                detail: '${snapshot.activeAdvertisements} إعلان ظاهر الآن',
                color: AppColors.advertisementGold,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionTitle(
            title: 'حالات الأنشطة',
            subtitle: 'نظرة سريعة على دورة الاعتماد',
          ),
          const SizedBox(height: AppSpacing.sm),
          _BusinessStatusSummary(snapshot: snapshot),
          const SizedBox(height: AppSpacing.lg),
          const _SectionTitle(
            title: 'إدارة النظام',
            subtitle: 'إدارة محتوى الدليل ومتابعة دورة الاعتماد',
          ),
          const SizedBox(height: AppSpacing.sm),
          _AdminModuleCard(
            key: const ValueKey<String>('admin-review-businesses-action'),
            icon: Icons.fact_check_rounded,
            title: 'مراجعة الأنشطة',
            subtitle: 'قبول الطلبات أو رفضها مع سبب واضح',
            badge: '${snapshot.pendingBusinesses} معلّق',
            color: AppColors.warning,
            onTap: _openBusinessReviews,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AdminModuleCard(
            key: const ValueKey<String>('admin-manage-businesses-action'),
            icon: Icons.store_mall_directory_rounded,
            title: 'إدارة الأنشطة',
            subtitle: 'إضافة الأنشطة وتعديلها وتمييزها وإيقافها أو حذفها',
            badge: '${snapshot.totalBusinesses} نشاط',
            color: AppColors.primaryTeal,
            onTap: _openBusinessManagement,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AdminModuleCard(
            key: const ValueKey<String>('admin-manage-categories-action'),
            icon: Icons.account_tree_rounded,
            title: 'إدارة الأقسام',
            subtitle: 'إضافة الأقسام وترتيبها وتفعيلها أو أرشفتها',
            badge: '${snapshot.activeCategories} نشط',
            color: AppColors.lightTeal,
            onTap: _openCategoryManagement,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AdminModuleCard(
            key: const ValueKey<String>('admin-manage-advertisements-action'),
            icon: Icons.campaign_rounded,
            title: 'إدارة الإعلانات',
            subtitle: 'المحتوى والروابط وفترات العرض وترتيب الظهور',
            badge: '${snapshot.activeAdvertisements} ظاهر',
            color: AppColors.advertisementGold,
            onTap: _openAdvertisementManagement,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AdminModuleCard(
            key: const ValueKey<String>('admin-manage-media-action'),
            icon: Icons.photo_library_rounded,
            title: 'إدارة الصور والوسائط',
            subtitle: 'مراجعة صور الأنشطة وتنظيف الملفات غير المستخدمة',
            badge: 'معرض وتنظيف',
            color: AppColors.primaryDark,
            onTap: _openMediaManagement,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AdminModuleCard(
            key: const ValueKey<String>('admin-system-usage-action'),
            icon: Icons.analytics_rounded,
            title: 'مراقبة النظام والاستهلاك',
            subtitle: 'قاعدة البيانات والتخزين وحدود الخطة المجانية',
            badge: 'Free',
            color: AppColors.primaryTeal,
            onTap: _openSystemUsage,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AdminModuleCard(
            key: const ValueKey<String>('admin-manage-users-action'),
            icon: Icons.manage_accounts_rounded,
            title: 'إدارة المستخدمين',
            subtitle: 'البحث والحالة والصلاحيات وسجل الإجراءات',
            badge: '${snapshot.activeUsers} نشط',
            color: AppColors.primaryDark,
            onTap: _openUserManagement,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AdminModuleCard(
            key: const ValueKey<String>('admin-manage-notifications-action'),
            icon: Icons.notifications_active_rounded,
            title: 'إدارة الإشعارات',
            subtitle: 'إرسال تنبيه عام أو لمستخدم محدد مع وجهة داخل التطبيق',
            badge: 'Firebase FCM',
            color: AppColors.primaryTeal,
            onTap: _openNotificationManagement,
          ),
          const SizedBox(height: AppSpacing.lg),
          _FoundationNotice(loadedAt: snapshot.loadedAt),
        ],
      ),
    );
  }

  Future<void> _openBusinessReviews() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AdminBusinessReviewPage(),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadDashboard();
  }

  Future<void> _openBusinessManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AdminBusinessManagementPage(),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadDashboard();
  }

  Future<void> _openCategoryManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AdminCategoryManagementPage(),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadDashboard();
  }

  Future<void> _openAdvertisementManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AdminAdvertisementManagementPage(),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadDashboard();
  }

  Future<void> _openMediaManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AdminMediaManagementPage(),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadDashboard();
  }

  Future<void> _openSystemUsage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AdminSystemUsagePage(),
      ),
    );
  }

  Future<void> _openNotificationManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AdminNotificationManagementPage(),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadDashboard();
  }

  Future<void> _openUserManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AdminUserManagementPage(),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadDashboard();
  }
}

class _AdminLoadingView extends StatelessWidget {
  const _AdminLoadingView();

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppSpacing.md),
          Text('جارٍ التحقق من صلاحية الإدارة…'),
        ],
      ),
    );
  }
}

class _AdminWelcomeCard extends StatelessWidget {
  const _AdminWelcomeCard({required this.profile});

  final AccountProfile profile;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.primaryDeep,
            AppColors.primaryDark,
            AppColors.primaryTeal,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.floating,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: AppColors.white,
              size: 33,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحبًا ${profile.fullName.trim().isEmpty ? 'بالمدير' : profile.fullName}',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  profile.email ?? 'حساب إداري موثّق',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'تم التحقق من الدور عبر Supabase وRLS',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveMetrics extends StatelessWidget {
  const _ResponsiveMetrics({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 760
            ? 4
            : width >= 480
                ? 2
                : 1;
        final gaps = AppSpacing.sm * (columns - 1);
        final cardWidth = (width - gaps) / columns;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: children
              .map((child) => SizedBox(width: cardWidth, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
  final int value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall),
                Text(
                  '$value',
                  style: AppTextStyles.headlineMedium.copyWith(color: color),
                ),
                Text(
                  detail,
                  maxLines: 2,
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

class _BusinessStatusSummary extends StatelessWidget {
  const _BusinessStatusSummary({required this.snapshot});

  final AdminDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _StatusChip(
          label: 'قيد المراجعة',
          count: snapshot.pendingBusinesses,
          color: AppColors.warning,
        ),
        _StatusChip(
          label: 'معتمد',
          count: snapshot.approvedBusinesses,
          color: AppColors.success,
        ),
        _StatusChip(
          label: 'مرفوض',
          count: snapshot.rejectedBusinesses,
          color: AppColors.danger,
        ),
        _StatusChip(
          label: 'يحتاج تعديل',
          count: snapshot.changesRequestedBusinesses,
          color: AppColors.warning,
        ),
        _StatusChip(
          label: 'مسودة',
          count: snapshot.draftBusinesses,
          color: AppColors.textSecondary,
        ),
        _StatusChip(
          label: 'موقوف',
          count: snapshot.suspendedBusinesses,
          color: AppColors.primaryDark,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$label: $count',
        style: AppTextStyles.labelMedium.copyWith(color: color),
      ),
    );
  }
}

class _AdminModuleCard extends StatelessWidget {
  const _AdminModuleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      badge,
                      style: AppTextStyles.labelSmall.copyWith(color: color),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.xxs),
        Text(subtitle, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _FoundationNotice extends StatelessWidget {
  const _FoundationNotice({required this.loadedAt});

  final DateTime loadedAt;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final localTime = loadedAt.toLocal();
    final time = '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            color: AppColors.primaryTeal,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'تم تفعيل مراجعة الأنشطة وإدارة الأقسام والأنشطة والإعلانات '
              'والوسائط والمستخدمين مع سجلات تدقيق محمية. '
              'آخر تحديث: $time.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminStateView extends StatelessWidget {
  const _AdminStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - AppSpacing.xxl)
                  .clamp(0.0, double.infinity)
                  .toDouble(),
            ),
            child: Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 520),
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
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 38),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(actionLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
