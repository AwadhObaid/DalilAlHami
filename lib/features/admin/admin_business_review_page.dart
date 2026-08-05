import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/admin_repository.dart';
import '../../models/account_profile.dart';
import '../../models/admin_business_review.dart';
import 'admin_business_review_detail_page.dart';

typedef AdminReviewProfileLoader = Future<AccountProfile> Function();
typedef AdminPendingBusinessesLoader = Future<List<AdminBusinessReviewItem>>
    Function();
typedef AdminBusinessDetailLoader = Future<AdminBusinessReviewItem> Function(
    String businessId);
typedef AdminBusinessReviewAction = Future<AdminBusinessReviewResult> Function(
  String businessId,
  AdminReviewDecision decision,
  String? reason,
);

class AdminBusinessReviewPage extends StatefulWidget {
  const AdminBusinessReviewPage({
    super.key,
    this.profileLoader,
    this.queueLoader,
    this.detailLoader,
    this.reviewAction,
  });

  final AdminReviewProfileLoader? profileLoader;
  final AdminPendingBusinessesLoader? queueLoader;
  final AdminBusinessDetailLoader? detailLoader;
  final AdminBusinessReviewAction? reviewAction;

  @override
  State<AdminBusinessReviewPage> createState() =>
      _AdminBusinessReviewPageState();
}

enum _ReviewQueueState {
  loading,
  ready,
  denied,
  failed,
}

class _AdminBusinessReviewPageState extends State<AdminBusinessReviewPage> {
  final AdminRepository _repository = AdminRepository();
  final TextEditingController _searchController = TextEditingController();

  _ReviewQueueState _state = _ReviewQueueState.loading;
  List<AdminBusinessReviewItem> _businesses = const <AdminBusinessReviewItem>[];
  String _query = '';
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQueue() async {
    if (mounted) {
      setState(() {
        _state = _ReviewQueueState.loading;
        _message = null;
      });
    }

    try {
      final profile = await (widget.profileLoader?.call() ??
          _repository.loadCurrentAdminProfile());
      if (!profile.isAdmin || !profile.isActive) {
        throw const AdminAccessDenied(
          'هذا الحساب لا يملك صلاحية مراجعة الأنشطة.',
        );
      }

      final businesses = await (widget.queueLoader?.call() ??
          _repository.loadPendingBusinesses());
      if (!mounted) {
        return;
      }
      setState(() {
        _businesses = businesses;
        _state = _ReviewQueueState.ready;
      });
    } on AdminAccessDenied catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _state = _ReviewQueueState.denied;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error is AdminRepositoryFailure
            ? error.message
            : 'تعذر تحميل الأنشطة المعلقة. تحقق من الاتصال ثم أعد المحاولة.';
        _state = _ReviewQueueState.failed;
      });
    }
  }

  List<AdminBusinessReviewItem> get _visibleBusinesses {
    final query = _normalize(_query);
    if (query.isEmpty) {
      return _businesses;
    }
    return _businesses.where((business) {
      final text = _normalize(
        '${business.name} ${business.categoryName} '
        '${business.displayOwnerName} ${business.phone} ${business.address}',
      );
      return text.contains(query);
    }).toList(growable: false);
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
  }

  Future<void> _openBusiness(AdminBusinessReviewItem business) async {
    final reviewed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AdminBusinessReviewDetailPage(
          initialBusiness: business,
          detailLoader: widget.detailLoader ??
              (businessId) => _repository.loadBusinessForReview(businessId),
          reviewAction: widget.reviewAction ??
              (businessId, decision, reason) => _repository.reviewBusiness(
                    businessId: businessId,
                    decision: decision,
                    reason: reason,
                  ),
        ),
      ),
    );

    if (!mounted || reviewed != true) {
      return;
    }
    await _loadQueue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('مراجعة الأنشطة'),
      ),
      body: switch (_state) {
        _ReviewQueueState.loading => const _ReviewQueueLoading(),
        _ReviewQueueState.denied => _ReviewQueueMessage(
            key: const ValueKey<String>('admin-review-access-denied'),
            icon: Icons.lock_person_rounded,
            title: 'غير مصرح بالدخول',
            message: _message ?? 'لا تملك صلاحية المراجعة.',
            color: AppColors.danger,
            actionLabel: 'العودة',
            onAction: () => Navigator.maybePop(context),
          ),
        _ReviewQueueState.failed => _ReviewQueueMessage(
            key: const ValueKey<String>('admin-review-load-error'),
            icon: Icons.cloud_off_rounded,
            title: 'تعذر تحميل قائمة المراجعة',
            message: _message ?? 'تحقق من الاتصال ثم أعد المحاولة.',
            color: AppColors.warning,
            actionLabel: 'إعادة المحاولة',
            onAction: _loadQueue,
          ),
        _ReviewQueueState.ready => _buildQueue(),
      },
    );
  }

  Widget _buildQueue() {
    final visible = _visibleBusinesses;

    return RefreshIndicator(
      onRefresh: _loadQueue,
      child: CustomScrollView(
        key: const PageStorageKey<String>('admin-business-review-queue'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _ReviewQueueHeader(pendingCount: _businesses.length),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: TextField(
                key: const ValueKey<String>('admin-review-search-field'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'ابحث باسم النشاط أو صاحبه أو القسم…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'مسح البحث',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
          ),
          if (_businesses.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyReviewQueue(),
            )
          else if (visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _NoSearchResults(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index.isOdd) {
                      return const SizedBox(height: AppSpacing.sm);
                    }
                    final business = visible[index ~/ 2];
                    return AdminPendingBusinessCard(
                      business: business,
                      onPressed: () => _openBusiness(business),
                    );
                  },
                  childCount: (visible.length * 2) - 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminPendingBusinessCard extends StatelessWidget {
  const AdminPendingBusinessCard({
    required this.business,
    required this.onPressed,
    super.key,
  });

  final AdminBusinessReviewItem business;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey<String>('admin-pending-business-${business.id}'),
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BusinessThumbnail(url: business.preferredImageUrl),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            business.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const _PendingBadge(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      business.categoryName.isEmpty
                          ? 'قسم غير محدد'
                          : business.categoryName,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _CompactInformation(
                      icon: Icons.person_outline_rounded,
                      text: business.displayOwnerName,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    _CompactInformation(
                      icon: Icons.location_on_outlined,
                      text: business.address,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatDate(business.createdAt),
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                        Text(
                          'فتح المراجعة',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primaryTeal,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 15,
                          color: AppColors.primaryTeal,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return 'أُرسل ${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _ReviewQueueHeader extends StatelessWidget {
  const _ReviewQueueHeader({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primaryDeep, AppColors.primaryTeal],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.floating,
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.fact_check_rounded,
              color: AppColors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلبات بانتظار القرار',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  pendingCount == 0
                      ? 'لا توجد طلبات معلقة الآن'
                      : '$pendingCount نشاط يحتاج المراجعة',
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

class _BusinessThumbnail extends StatelessWidget {
  const _BusinessThumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 78,
        height: 78,
        child: url.trim().isEmpty
            ? const _ThumbnailPlaceholder()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _ThumbnailPlaceholder(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const _ThumbnailPlaceholder(showProgress: true);
                },
              ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({this.showProgress = false});

  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.primarySoft),
      child: Center(
        child: showProgress
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.storefront_rounded,
                color: AppColors.primaryTeal,
                size: 34,
              ),
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'معلّق',
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning),
      ),
    );
  }
}

class _CompactInformation extends StatelessWidget {
  const _CompactInformation({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ReviewQueueLoading extends StatelessWidget {
  const _ReviewQueueLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppSpacing.md),
          Text('جارٍ تحميل طلبات المراجعة…'),
        ],
      ),
    );
  }
}

class _EmptyReviewQueue extends StatelessWidget {
  const _EmptyReviewQueue();

  @override
  Widget build(BuildContext context) {
    return const _CenteredQueueState(
      icon: Icons.task_alt_rounded,
      title: 'لا توجد أنشطة معلقة',
      message: 'تمت مراجعة جميع الطلبات الحالية.',
      color: AppColors.success,
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return const _CenteredQueueState(
      icon: Icons.search_off_rounded,
      title: 'لا توجد نتيجة مطابقة',
      message: 'غيّر عبارة البحث أو امسحها لعرض جميع الطلبات.',
      color: AppColors.textSecondary,
    );
  }
}

class _CenteredQueueState extends StatelessWidget {
  const _CenteredQueueState({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: color),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ReviewQueueMessage extends StatelessWidget {
  const _ReviewQueueMessage({
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(icon, size: 62, color: color),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
