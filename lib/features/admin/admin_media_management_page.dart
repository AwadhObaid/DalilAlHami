import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/admin_media_repository.dart';
import '../../models/admin_media_overview.dart';
import '../shared/widgets/cached_directory_image.dart';

typedef AdminMediaOverviewLoader = Future<AdminMediaOverview> Function();
typedef AdminMediaCleanupLoader = Future<List<AdminMediaCleanupCandidate>>
    Function();
typedef AdminMediaCleanupExecutor = Future<AdminMediaCleanupResult> Function(
  List<AdminMediaCleanupCandidate> candidates,
);

class AdminMediaManagementPage extends StatefulWidget {
  const AdminMediaManagementPage({
    super.key,
    this.overviewLoader,
    this.cleanupLoader,
    this.cleanupExecutor,
  });

  final AdminMediaOverviewLoader? overviewLoader;
  final AdminMediaCleanupLoader? cleanupLoader;
  final AdminMediaCleanupExecutor? cleanupExecutor;

  @override
  State<AdminMediaManagementPage> createState() =>
      _AdminMediaManagementPageState();
}

class _AdminMediaManagementPageState extends State<AdminMediaManagementPage> {
  final AdminMediaRepository _repository = AdminMediaRepository();

  AdminMediaOverview? _overview;
  List<AdminMediaCleanupCandidate> _cleanupCandidates =
      const <AdminMediaCleanupCandidate>[];
  String? _errorMessage;
  bool _isLoading = true;
  bool _isScanning = false;
  bool _isCleaning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final overview =
          await (widget.overviewLoader?.call() ?? _repository.loadOverview());
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = overview;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _friendlyMessage(error);
        _isLoading = false;
      });
    }
  }

  String _friendlyMessage(Object error) {
    if (error is AdminMediaRepositoryFailure) {
      return error.message;
    }
    return 'تعذر تحميل إدارة الوسائط. تحقق من الاتصال ثم أعد المحاولة.';
  }

  Future<void> _scanCleanupCandidates() async {
    setState(() {
      _isScanning = true;
    });
    try {
      final candidates = await (widget.cleanupLoader?.call() ??
          _repository.loadCleanupCandidates());
      if (!mounted) {
        return;
      }
      setState(() {
        _cleanupCandidates = candidates;
        _isScanning = false;
      });
      if (candidates.isEmpty) {
        _showMessage('لا توجد ملفات يتيمة أو مسودات منتهية حاليًا.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isScanning = false;
      });
      _showMessage(_friendlyMessage(error), isError: true);
    }
  }

  Future<void> _confirmCleanup() async {
    if (_cleanupCandidates.isEmpty || _isCleaning) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تنظيف الملفات غير المستخدمة'),
        content: Text(
          'سيتم حذف ${_cleanupCandidates.length} ملفًا من التخزين نهائيًا. '
          'لن تتضمن القائمة أي صورة مرتبطة بسجل نشط.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const ValueKey<String>('admin-media-cleanup-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف الملفات'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isCleaning = true;
    });
    try {
      final result = await (widget.cleanupExecutor?.call(
            _cleanupCandidates,
          ) ??
          _repository.cleanupCandidates(_cleanupCandidates));
      if (!mounted) {
        return;
      }
      setState(() {
        _cleanupCandidates = result.failed;
        _isCleaning = false;
      });
      if (result.isComplete) {
        _showMessage('تم حذف ${result.deletedCount} ملفًا غير مستخدم.');
      } else {
        _showMessage(
          'حُذف ${result.deletedCount} ملفًا، وتعذر حذف '
          '${result.failed.length} ملفًا.',
          isError: true,
        );
      }
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCleaning = false;
      });
      _showMessage(_friendlyMessage(error), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.danger : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('إدارة الصور والوسائط'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _overview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_overview == null) {
      return _MediaStateView(
        key: const ValueKey<String>('admin-media-error'),
        message: _errorMessage ?? 'تعذر تحميل بيانات الوسائط.',
        onRetry: _load,
      );
    }

    final overview = _overview!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const PageStorageKey<String>('admin-media-management-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          _MediaSummaryCard(overview: overview),
          const SizedBox(height: AppSpacing.lg),
          Text('توزيع الصور', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          _MediaMetricGrid(overview: overview),
          const SizedBox(height: AppSpacing.lg),
          _CleanupPanel(
            candidates: _cleanupCandidates,
            isScanning: _isScanning,
            isCleaning: _isCleaning,
            onScan: _scanCleanupCandidates,
            onClean: _confirmCleanup,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('أحدث صور الأنشطة', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          if (overview.recentGallery.isEmpty)
            const _EmptyRecentGallery()
          else
            ...overview.recentGallery.map(
              (image) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _RecentGalleryTile(image: image),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaSummaryCard extends StatelessWidget {
  const _MediaSummaryCard({required this.overview});

  final AdminMediaOverview overview;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('admin-media-summary'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDeep, AppColors.primaryTeal],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          const Icon(Icons.photo_library_rounded,
              color: AppColors.white, size: 42),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${overview.totalReferencedImages} صورة مرتبطة',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.white,
                  ),
                ),
                Text(
                  '${overview.galleryImages} صورة داخل معارض الأنشطة',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withValues(alpha: 0.84),
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

class _MediaMetricGrid extends StatelessWidget {
  const _MediaMetricGrid({required this.overview});

  final AdminMediaOverview overview;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, int count})>[
      (
        icon: Icons.account_circle_rounded,
        title: 'الصور الشخصية',
        count: overview.profileAvatars,
      ),
      (
        icon: Icons.category_rounded,
        title: 'صور الأقسام',
        count: overview.categoryImages
      ),
      (
        icon: Icons.business_rounded,
        title: 'شعارات الأنشطة',
        count: overview.businessLogos
      ),
      (
        icon: Icons.panorama_rounded,
        title: 'أغلفة الأنشطة',
        count: overview.businessCovers
      ),
      (
        icon: Icons.collections_rounded,
        title: 'صور المعرض',
        count: overview.galleryImages
      ),
      (
        icon: Icons.campaign_rounded,
        title: 'صور الإعلانات',
        count: overview.advertisementImages
      ),
      (
        icon: Icons.view_stream_rounded,
        title: 'إعلانات مصغرة',
        count: overview.compactAdvertisementImages
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680
            ? 3
            : constraints.maxWidth >= 420
                ? 2
                : 1;
        final width =
            (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _MediaMetricTile(
                    icon: item.icon,
                    title: item.title,
                    count: item.count,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _MediaMetricTile extends StatelessWidget {
  const _MediaMetricTile({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

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
        children: [
          Icon(icon, color: AppColors.primaryTeal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(title, style: AppTextStyles.titleSmall)),
          Text('$count', style: AppTextStyles.titleLarge),
        ],
      ),
    );
  }
}

class _CleanupPanel extends StatelessWidget {
  const _CleanupPanel({
    required this.candidates,
    required this.isScanning,
    required this.isCleaning,
    required this.onScan,
    required this.onClean,
  });

  final List<AdminMediaCleanupCandidate> candidates;
  final bool isScanning;
  final bool isCleaning;
  final VoidCallback onScan;
  final VoidCallback onClean;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('admin-media-cleanup-panel'),
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
              const Icon(Icons.cleaning_services_rounded,
                  color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('تنظيف التخزين', style: AppTextStyles.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'يفحص المسودات الأقدم من 24 ساعة والملفات غير المرتبطة '
            'بالملفات الشخصية أو الأقسام أو الأنشطة أو الإعلانات.',
            style: AppTextStyles.bodySmall,
          ),
          if (candidates.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'تم العثور على ${candidates.length} ملفًا قابلًا للتنظيف.',
              key: const ValueKey<String>('admin-media-cleanup-count'),
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                key: const ValueKey<String>('admin-media-scan-action'),
                onPressed: isScanning || isCleaning ? null : onScan,
                icon: isScanning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: const Text('فحص التخزين'),
              ),
              FilledButton.icon(
                key: const ValueKey<String>('admin-media-cleanup-action'),
                onPressed: candidates.isEmpty || isCleaning ? null : onClean,
                icon: isCleaning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_sweep_rounded),
                label: const Text('تنظيف الملفات'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentGalleryTile extends StatelessWidget {
  const _RecentGalleryTile({required this.image});

  final AdminRecentGalleryImage image;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: CachedDirectoryImage(
              source: image.publicUrl.isNotEmpty
                  ? image.publicUrl
                  : image.storagePath,
              bucket: 'business-media',
              width: 84,
              height: 64,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  image.businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall,
                ),
                Text(
                  image.altText.isEmpty ? 'دون وصف بديل' : image.altText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          if (image.isPrimary)
            const Tooltip(
              message: 'الصورة الرئيسية',
              child:
                  Icon(Icons.star_rounded, color: AppColors.advertisementGold),
            ),
        ],
      ),
    );
  }
}

class _EmptyRecentGallery extends StatelessWidget {
  const _EmptyRecentGallery();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: const Column(
        children: [
          Icon(Icons.photo_library_outlined,
              color: AppColors.primaryTeal, size: 36),
          SizedBox(height: AppSpacing.sm),
          Text('لا توجد صور معرض مضافة بعد.'),
        ],
      ),
    );
  }
}

class _MediaStateView extends StatelessWidget {
  const _MediaStateView({
    super.key,
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
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.warning, size: 42),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
                onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
