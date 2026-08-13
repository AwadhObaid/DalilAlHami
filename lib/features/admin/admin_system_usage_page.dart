import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localized_text.dart' show AppLocaleText;
import '../../data/repositories/admin_system_usage_repository.dart';
import '../../models/admin_system_usage.dart';

typedef AdminSystemUsageLoader = Future<AdminSystemUsageSnapshot> Function();

class AdminSystemUsagePage extends StatefulWidget {
  const AdminSystemUsagePage({
    super.key,
    this.loader,
  });

  final AdminSystemUsageLoader? loader;

  @override
  State<AdminSystemUsagePage> createState() => _AdminSystemUsagePageState();
}

class _AdminSystemUsagePageState extends State<AdminSystemUsagePage> {
  static const int _freeDatabaseLimitBytes = 500000000;
  static const int _freeStorageLimitBytes = 1000000000;

  final AdminSystemUsageRepository _repository = AdminSystemUsageRepository();

  AdminSystemUsageSnapshot? _snapshot;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = _snapshot == null;
        _errorMessage = null;
      });
    }

    try {
      final snapshot =
          await (widget.loader?.call() ?? _repository.loadSnapshot());
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error is AdminSystemUsageRepositoryFailure
            ? error.message
            : _pick(
                'تعذر تحميل مؤشرات النظام. تحقق من الاتصال ثم أعد المحاولة.',
                'Could not load system metrics. Check your connection and try again.',
              );
        _isLoading = false;
      });
    }
  }

  String _pick(String ar, String en) {
    if (!mounted) {
      return ar;
    }
    return AppLocaleText.pick(context, ar: ar, en: en);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        appBar: AppBar(
          title: Text(
            AppLocaleText.pick(
              context,
              ar: 'مراقبة النظام والاستهلاك',
              en: 'System & usage monitoring',
            ),
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            dividerColor: Colors.white24,
            tabs: [
              Tab(
                text: AppLocaleText.pick(
                  context,
                  ar: 'نظرة عامة',
                  en: 'Overview',
                ),
              ),
              Tab(
                text: AppLocaleText.pick(
                  context,
                  ar: 'قاعدة البيانات',
                  en: 'Database',
                ),
              ),
              Tab(
                text: AppLocaleText.pick(
                  context,
                  ar: 'التخزين',
                  en: 'Storage',
                ),
              ),
            ],
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppLocaleText.pick(
                context,
                ar: 'جارٍ تحميل مؤشرات النظام…',
                en: 'Loading system metrics…',
              ),
            ),
          ],
        ),
      );
    }

    if (_snapshot == null) {
      return _ErrorView(
        message: _errorMessage ??
            AppLocaleText.pick(
              context,
              ar: 'تعذر تحميل مؤشرات النظام.',
              en: 'Could not load system metrics.',
            ),
        onRetry: _load,
      );
    }

    final snapshot = _snapshot!;
    return TabBarView(
      children: [
        _OverviewTab(
          snapshot: snapshot,
          databaseLimitBytes: _freeDatabaseLimitBytes,
          storageLimitBytes: _freeStorageLimitBytes,
          onRefresh: _load,
        ),
        _DatabaseTab(
          snapshot: snapshot,
          databaseLimitBytes: _freeDatabaseLimitBytes,
          onRefresh: _load,
        ),
        _StorageTab(
          snapshot: snapshot,
          storageLimitBytes: _freeStorageLimitBytes,
          onRefresh: _load,
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.snapshot,
    required this.databaseLimitBytes,
    required this.storageLimitBytes,
    required this.onRefresh,
  });

  final AdminSystemUsageSnapshot snapshot;
  final int databaseLimitBytes;
  final int storageLimitBytes;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const PageStorageKey<String>('admin-system-usage-overview'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          _SectionHeader(
            title: AppLocaleText.pick(
              context,
              ar: 'حدود Free المرجعية',
              en: 'Free plan reference limits',
            ),
            subtitle: AppLocaleText.pick(
              context,
              ar: 'تُقارن الأرقام الفعلية الحالية بالحدود المجانية المعتمدة.',
              en: 'Current measured usage is compared with the Free plan limits.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _UsageProgressCard(
            key: const ValueKey<String>('admin-usage-database-card'),
            icon: Icons.storage_rounded,
            title: AppLocaleText.pick(
              context,
              ar: 'قاعدة البيانات الحالية',
              en: 'Current database',
            ),
            usedBytes: snapshot.databaseBytes,
            limitBytes: databaseLimitBytes,
          ),
          const SizedBox(height: AppSpacing.sm),
          _UsageProgressCard(
            key: const ValueKey<String>('admin-usage-storage-card'),
            icon: Icons.photo_library_rounded,
            title: AppLocaleText.pick(
              context,
              ar: 'تخزين الصور والملفات',
              en: 'Image & file storage',
            ),
            usedBytes: snapshot.storageBytes,
            limitBytes: storageLimitBytes,
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoCard(
            icon: Icons.swap_vert_circle_outlined,
            title: AppLocaleText.pick(
              context,
              ar: 'Egress الشهري',
              en: 'Monthly egress',
            ),
            value: AppLocaleText.pick(
              context,
              ar: 'غير متاح تلقائيًا',
              en: 'Not automatically available',
            ),
            body: AppLocaleText.pick(
              context,
              ar: 'يحتاج Management API من جهة الخادم؛ لا يتم تقديره داخل PostgreSQL حتى لا نعرض رقمًا مضللًا.',
              en: 'It requires the server-side Management API; PostgreSQL does not estimate it so the page never shows a misleading billing number.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
            title: AppLocaleText.pick(
              context,
              ar: 'ملخص المحتوى',
              en: 'Content summary',
            ),
            subtitle: AppLocaleText.pick(
              context,
              ar: 'قراءة إدارية مباشرة من قاعدة دليل الحامي.',
              en: 'Direct administrative read from the Al Hami Guide database.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _CountGrid(snapshot: snapshot),
          const SizedBox(height: AppSpacing.lg),
          _InfoCard(
            icon: Icons.schedule_rounded,
            title: AppLocaleText.pick(
              context,
              ar: 'آخر قراءة',
              en: 'Last snapshot',
            ),
            value: _formatDate(snapshot.capturedAt.toLocal()),
            body: AppLocaleText.pick(
              context,
              ar: 'اسحب الصفحة للأسفل لتحديث الأرقام مباشرة من Supabase.',
              en: 'Pull down to refresh the values directly from Supabase.',
            ),
          ),
        ],
      ),
    );
  }
}

class _DatabaseTab extends StatelessWidget {
  const _DatabaseTab({
    required this.snapshot,
    required this.databaseLimitBytes,
    required this.onRefresh,
  });

  final AdminSystemUsageSnapshot snapshot;
  final int databaseLimitBytes;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const PageStorageKey<String>('admin-system-usage-database'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          _UsageProgressCard(
            icon: Icons.data_usage_rounded,
            title: AppLocaleText.pick(
              context,
              ar: 'استخدام قاعدة البيانات',
              en: 'Database usage',
            ),
            usedBytes: snapshot.databaseBytes,
            limitBytes: databaseLimitBytes,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
            title: AppLocaleText.pick(
              context,
              ar: 'أحجام الجداول',
              en: 'Table sizes',
            ),
            subtitle: AppLocaleText.pick(
              context,
              ar: 'عدد الصفوف تقديري من إحصاءات PostgreSQL، بينما الحجم يشمل الجدول والفهارس.',
              en: 'Row counts are PostgreSQL estimates; size includes the table and its indexes.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (snapshot.tableUsage.isEmpty)
            _EmptyCard(
              text: AppLocaleText.pick(
                context,
                ar: 'لا توجد بيانات جداول متاحة.',
                en: 'No table metrics are available.',
              ),
            )
          else
            ...snapshot.tableUsage.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _MetricListTile(
                  icon: Icons.table_rows_rounded,
                  title: _tableLabel(context, item.tableName),
                  trailing: _formatBytes(item.bytes),
                  subtitle: AppLocaleText.pick(
                    context,
                    ar: '${item.rowCount} صف تقريبي',
                    en: '~${item.rowCount} rows',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StorageTab extends StatelessWidget {
  const _StorageTab({
    required this.snapshot,
    required this.storageLimitBytes,
    required this.onRefresh,
  });

  final AdminSystemUsageSnapshot snapshot;
  final int storageLimitBytes;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const PageStorageKey<String>('admin-system-usage-storage'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          _UsageProgressCard(
            icon: Icons.cloud_outlined,
            title: AppLocaleText.pick(
              context,
              ar: 'استخدام التخزين',
              en: 'Storage usage',
            ),
            usedBytes: snapshot.storageBytes,
            limitBytes: storageLimitBytes,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
            title: AppLocaleText.pick(
              context,
              ar: 'توزيع التخزين حسب Bucket',
              en: 'Storage by bucket',
            ),
            subtitle: AppLocaleText.pick(
              context,
              ar: 'يعرض حجم الملفات الحقيقي وعددها داخل كل حاوية.',
              en: 'Shows the actual file size and file count in each bucket.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (snapshot.bucketUsage.isEmpty)
            _EmptyCard(
              text: AppLocaleText.pick(
                context,
                ar: 'تعذر تحميل توزيع الحاويات. اسحب للأسفل لإعادة القراءة.',
                en: 'Bucket distribution is unavailable. Pull down to refresh.',
              ),
            )
          else
            ...snapshot.bucketUsage.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _MetricListTile(
                  icon: _bucketIcon(item.bucketId),
                  title: _bucketLabel(context, item.bucketId),
                  trailing: _formatBytes(item.bytes),
                  subtitle: AppLocaleText.pick(
                    context,
                    ar: '${item.fileCount} ملف',
                    en: '${item.fileCount} files',
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
            title: AppLocaleText.pick(
              context,
              ar: 'أكبر الملفات',
              en: 'Largest files',
            ),
            subtitle: AppLocaleText.pick(
              context,
              ar: 'أكبر 10 ملفات في Storage تساعد على اكتشاف الصور غير الطبيعية.',
              en: 'The 10 largest Storage files help identify unusually large images.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (snapshot.topFiles.isEmpty)
            _EmptyCard(
              text: AppLocaleText.pick(
                context,
                ar: 'لا توجد ملفات مخزنة حاليًا.',
                en: 'There are no stored files.',
              ),
            )
          else
            ...snapshot.topFiles.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _MetricListTile(
                  icon: Icons.image_outlined,
                  title: item.fileName,
                  trailing: _formatBytes(item.bytes),
                  subtitle: _bucketLabel(context, item.bucketId),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UsageProgressCard extends StatelessWidget {
  const _UsageProgressCard({
    super.key,
    required this.icon,
    required this.title,
    required this.usedBytes,
    required this.limitBytes,
  });

  final IconData icon;
  final String title;
  final int usedBytes;
  final int limitBytes;

  @override
  Widget build(BuildContext context) {
    final ratio = limitBytes <= 0 ? 0.0 : usedBytes / limitBytes;
    final progress = ratio.clamp(0.0, 1.0).toDouble();
    final color = _usageColor(ratio);
    final percentage = (ratio * 100).clamp(0, 999).toStringAsFixed(
          ratio >= 0.1 ? 1 : 2,
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                _statusLabel(context, ratio),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${_formatBytes(usedBytes)} / ${_formatBytes(limitBytes)}',
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.outline.withValues(alpha: 0.35),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$percentage%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String value;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryTeal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountGrid extends StatelessWidget {
  const _CountGrid({required this.snapshot});

  final AdminSystemUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, int value})>[
      (
        icon: Icons.people_alt_outlined,
        label: AppLocaleText.pick(
          context,
          ar: 'حسابات مسجلة',
          en: 'Registered accounts',
        ),
        value: snapshot.count('registered_users'),
      ),
      (
        icon: Icons.verified_user_outlined,
        label: AppLocaleText.pick(
          context,
          ar: 'حسابات نشطة',
          en: 'Active accounts',
        ),
        value: snapshot.count('active_users'),
      ),
      (
        icon: Icons.storefront_outlined,
        label: AppLocaleText.pick(context, ar: 'الأنشطة', en: 'Businesses'),
        value: snapshot.count('businesses'),
      ),
      (
        icon: Icons.campaign_outlined,
        label:
            AppLocaleText.pick(context, ar: 'الإعلانات', en: 'Advertisements'),
        value: snapshot.count('advertisements'),
      ),
      (
        icon: Icons.photo_library_outlined,
        label: AppLocaleText.pick(
          context,
          ar: 'صور الأنشطة',
          en: 'Business images',
        ),
        value: snapshot.count('business_images'),
      ),
      (
        icon: Icons.category_outlined,
        label: AppLocaleText.pick(context, ar: 'الأقسام', en: 'Categories'),
        value: snapshot.count('categories'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: AppColors.primaryTeal),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${item.value}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricListTile extends StatelessWidget {
  const _MetricListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryTeal),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          trailing,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Center(child: Text(text)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppLocaleText.pick(
                context,
                ar: 'تعذر تحميل مؤشرات النظام',
                en: 'Could not load system metrics',
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                AppLocaleText.pick(
                  context,
                  ar: 'إعادة المحاولة',
                  en: 'Try again',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _usageColor(double ratio) {
  if (ratio >= 0.90) {
    return AppColors.danger;
  }
  if (ratio >= 0.60) {
    return AppColors.warning;
  }
  return AppColors.success;
}

String _statusLabel(BuildContext context, double ratio) {
  if (ratio >= 0.90) {
    return AppLocaleText.pick(context, ar: 'حرج', en: 'Critical');
  }
  if (ratio >= 0.75) {
    return AppLocaleText.pick(context, ar: 'تحذير', en: 'Warning');
  }
  if (ratio >= 0.60) {
    return AppLocaleText.pick(context, ar: 'مراقبة', en: 'Watch');
  }
  return AppLocaleText.pick(context, ar: 'طبيعي', en: 'Normal');
}

String _formatBytes(int bytes) {
  final value = bytes < 0 ? 0 : bytes;
  const kb = 1000.0;
  const mb = 1000000.0;
  const gb = 1000000000.0;

  if (value >= gb) {
    return '${(value / gb).toStringAsFixed(2)} GB';
  }
  if (value >= mb) {
    return '${(value / mb).toStringAsFixed(2)} MB';
  }
  if (value >= kb) {
    return '${(value / kb).toStringAsFixed(1)} KB';
  }
  return '$value B';
}

String _formatDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

IconData _bucketIcon(String bucketId) {
  return switch (bucketId) {
    'advertisements' => Icons.campaign_outlined,
    'avatars' => Icons.account_circle_outlined,
    'category-media' => Icons.category_outlined,
    _ => Icons.photo_library_outlined,
  };
}

String _bucketLabel(BuildContext context, String bucketId) {
  return switch (bucketId) {
    'business-media' => AppLocaleText.pick(
        context,
        ar: 'صور الأنشطة',
        en: 'Business media',
      ),
    'advertisements' => AppLocaleText.pick(
        context,
        ar: 'صور الإعلانات',
        en: 'Advertisement images',
      ),
    'avatars' => AppLocaleText.pick(
        context,
        ar: 'الصور الشخصية',
        en: 'Profile photos',
      ),
    'category-media' => AppLocaleText.pick(
        context,
        ar: 'صور الأقسام',
        en: 'Category images',
      ),
    _ => bucketId,
  };
}

String _tableLabel(BuildContext context, String tableName) {
  return switch (tableName) {
    'profiles' => AppLocaleText.pick(context, ar: 'المستخدمون', en: 'Users'),
    'categories' =>
      AppLocaleText.pick(context, ar: 'الأقسام', en: 'Categories'),
    'businesses' =>
      AppLocaleText.pick(context, ar: 'الأنشطة', en: 'Businesses'),
    'business_images' => AppLocaleText.pick(
        context,
        ar: 'صور الأنشطة',
        en: 'Business images',
      ),
    'advertisements' => AppLocaleText.pick(
        context,
        ar: 'الإعلانات',
        en: 'Advertisements',
      ),
    'app_notifications' => AppLocaleText.pick(
        context,
        ar: 'الإشعارات',
        en: 'Notifications',
      ),
    'app_notification_reads' => AppLocaleText.pick(
        context,
        ar: 'حالات قراءة الإشعارات',
        en: 'Notification reads',
      ),
    'favorites' => AppLocaleText.pick(
        context,
        ar: 'المفضلة',
        en: 'Favorites',
      ),
    'business_ratings' => AppLocaleText.pick(
        context,
        ar: 'تقييمات الأنشطة',
        en: 'Business ratings',
      ),
    'reports' => AppLocaleText.pick(
        context,
        ar: 'البلاغات',
        en: 'Reports',
      ),
    'device_tokens' => AppLocaleText.pick(
        context,
        ar: 'رموز الأجهزة',
        en: 'Device tokens',
      ),
    'push_notification_devices' => AppLocaleText.pick(
        context,
        ar: 'أجهزة الإشعارات',
        en: 'Push devices',
      ),
    _ => tableName,
  };
}
