import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/admin_content_repository.dart';
import '../../data/repositories/admin_repository.dart';
import '../../models/account_profile.dart';
import '../../models/admin_advertisement_management.dart';
import '../../models/admin_content_management.dart';
import 'admin_advertisement_form_page.dart';

typedef AdminAdvertisementsLoader = Future<List<AdminAdvertisementItem>>
    Function();
typedef AdminAdvertisementBusinessesLoader
    = Future<List<AdminAdvertisementBusinessOption>> Function();
typedef AdminAdvertisementActivationAction = Future<AdminContentMutationResult>
    Function(String advertisementId, bool isActive);
typedef AdminAdvertisementDeleteAction = Future<AdminContentMutationResult>
    Function(String advertisementId);

class AdminAdvertisementManagementPage extends StatefulWidget {
  const AdminAdvertisementManagementPage({
    super.key,
    this.profileLoader,
    this.advertisementsLoader,
    this.businessesLoader,
    this.saveAction,
    this.activationAction,
    this.deleteAction,
  });

  final Future<AccountProfile> Function()? profileLoader;
  final AdminAdvertisementsLoader? advertisementsLoader;
  final AdminAdvertisementBusinessesLoader? businessesLoader;
  final AdminAdvertisementSaveAction? saveAction;
  final AdminAdvertisementActivationAction? activationAction;
  final AdminAdvertisementDeleteAction? deleteAction;

  @override
  State<AdminAdvertisementManagementPage> createState() =>
      _AdminAdvertisementManagementPageState();
}

enum _AdvertisementPageState { loading, ready, denied, failed }

enum _AdvertisementFilter {
  all,
  visible,
  scheduled,
  ended,
  inactive,
}

class _AdminAdvertisementManagementPageState
    extends State<AdminAdvertisementManagementPage> {
  final AdminRepository _adminRepository = AdminRepository();
  final AdminContentRepository _contentRepository = AdminContentRepository();
  final TextEditingController _searchController = TextEditingController();

  _AdvertisementPageState _state = _AdvertisementPageState.loading;
  _AdvertisementFilter _filter = _AdvertisementFilter.all;
  List<AdminAdvertisementItem> _advertisements =
      const <AdminAdvertisementItem>[];
  List<AdminAdvertisementBusinessOption> _businesses =
      const <AdminAdvertisementBusinessOption>[];
  AdminAdvertisementPlacement? _placementFilter;
  String _query = '';
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _state = _AdvertisementPageState.loading;
        _message = null;
      });
    }

    try {
      final profile = await (widget.profileLoader?.call() ??
          _adminRepository.loadCurrentAdminProfile());
      if (!profile.isAdmin || !profile.isActive) {
        throw const AdminAccessDenied('لا تملك صلاحية إدارة الإعلانات.');
      }

      final results = await Future.wait<Object>([
        widget.advertisementsLoader?.call() ??
            _contentRepository.loadAdvertisements(),
        widget.businessesLoader?.call() ??
            _contentRepository.loadAdvertisementBusinesses(),
      ]);

      if (!mounted) return;
      setState(() {
        _advertisements = results[0] as List<AdminAdvertisementItem>;
        _businesses = results[1] as List<AdminAdvertisementBusinessOption>;
        _state = _AdvertisementPageState.ready;
      });
    } on AdminAccessDenied catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _state = _AdvertisementPageState.denied;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _errorMessage(error);
        _state = _AdvertisementPageState.failed;
      });
    }
  }

  List<AdminAdvertisementItem> get _visibleAdvertisements {
    final now = DateTime.now().toUtc();
    final query = _normalize(_query);

    return _advertisements.where((advertisement) {
      if (_placementFilter != null &&
          advertisement.placement != _placementFilter) {
        return false;
      }

      final state = advertisement.runtimeStateAt(now);
      final matchesState = switch (_filter) {
        _AdvertisementFilter.all => true,
        _AdvertisementFilter.visible =>
          state == AdminAdvertisementRuntimeState.visible,
        _AdvertisementFilter.scheduled =>
          state == AdminAdvertisementRuntimeState.scheduled,
        _AdvertisementFilter.ended =>
          state == AdminAdvertisementRuntimeState.ended,
        _AdvertisementFilter.inactive =>
          state == AdminAdvertisementRuntimeState.inactive,
      };
      if (!matchesState) return false;

      if (query.isEmpty) return true;
      return _normalize(
        '${advertisement.title} ${advertisement.placement.label} '
        '${advertisement.targetLabel} ${advertisement.imagePath}',
      ).contains(query);
    }).toList(growable: false);
  }

  Future<void> _openForm([AdminAdvertisementItem? advertisement]) async {
    final result = await Navigator.of(context).push<AdminContentMutationResult>(
      MaterialPageRoute<AdminContentMutationResult>(
        builder: (_) => AdminAdvertisementFormPage(
          businesses: _businesses,
          initialAdvertisement: advertisement,
          onSave: widget.saveAction ?? _contentRepository.saveAdvertisement,
        ),
      ),
    );
    if (!mounted || result == null) return;
    _showMessage(result.message);
    await _load();
  }

  Future<void> _setActive(
    AdminAdvertisementItem advertisement,
    bool isActive,
  ) async {
    final verb = isActive ? 'تفعيل' : 'إيقاف';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$verb الإعلان'),
        content: Text(
          isActive
              ? 'سيعود «${advertisement.title}» للظهور عندما تكون فترة عرضه صالحة.'
              : 'سيتوقف «${advertisement.title}» فور وصول المزامنة إلى الأجهزة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: ValueKey<String>(
              isActive
                  ? 'admin-advertisement-activate-confirm'
                  : 'admin-advertisement-deactivate-confirm',
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(verb),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await (widget.activationAction?.call(
            advertisement.id,
            isActive,
          ) ??
          _contentRepository.setAdvertisementActive(
            advertisementId: advertisement.id,
            isActive: isActive,
          ));
      if (!mounted) return;
      _showMessage(result.message);
      await _load();
    } catch (error) {
      _showMessage(_errorMessage(error), error: true);
    }
  }

  Future<void> _deleteAdvertisement(
    AdminAdvertisementItem advertisement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الإعلان نهائيًا'),
        content: Text(
          'سيُحذف «${advertisement.title}» نهائيًا، وسيصل الحذف إلى الأجهزة '
          'عبر نظام المزامنة. لا يمكن التراجع عن هذه العملية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const ValueKey<String>(
              'admin-advertisement-delete-confirm',
            ),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await (widget.deleteAction?.call(advertisement.id) ??
          _contentRepository.deleteAdvertisement(advertisement.id));
      if (!mounted) return;
      _showMessage(result.message);
      await _load();
    } catch (error) {
      _showMessage(_errorMessage(error), error: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: error ? AppColors.danger : null,
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _errorMessage(Object error) {
    if (error is AdminContentRepositoryFailure) return error.message;
    if (error is AdminRepositoryFailure) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('إدارة الإعلانات')),
      body: switch (_state) {
        _AdvertisementPageState.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        _AdvertisementPageState.denied => _AdvertisementStateView(
            key: const ValueKey<String>('admin-advertisements-denied'),
            icon: Icons.lock_person_rounded,
            title: 'غير مصرح بالدخول',
            message: _message ?? 'لا تملك صلاحية إدارة الإعلانات.',
            onRetry: () => Navigator.maybePop(context),
            actionLabel: 'العودة',
          ),
        _AdvertisementPageState.failed => _AdvertisementStateView(
            key: const ValueKey<String>('admin-advertisements-error'),
            icon: Icons.cloud_off_rounded,
            title: 'تعذر تحميل الإعلانات',
            message: _message ?? 'تحقق من الاتصال ثم أعد المحاولة.',
            onRetry: _load,
            actionLabel: 'إعادة المحاولة',
          ),
        _AdvertisementPageState.ready => _buildContent(),
      },
      floatingActionButton: _state == _AdvertisementPageState.ready
          ? FloatingActionButton.extended(
              key: const ValueKey<String>('admin-add-advertisement-button'),
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إعلان جديد'),
            )
          : null,
    );
  }

  Widget _buildContent() {
    final visible = _visibleAdvertisements;
    final now = DateTime.now().toUtc();
    final visibleCount = _advertisements
        .where((advertisement) => advertisement.isVisibleAt(now))
        .length;
    final scheduledCount = _advertisements
        .where(
          (advertisement) =>
              advertisement.runtimeStateAt(now) ==
              AdminAdvertisementRuntimeState.scheduled,
        )
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const ValueKey<String>('admin-advertisements-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          104,
        ),
        children: [
          _AdvertisementSummary(
            total: _advertisements.length,
            visible: visibleCount,
            scheduled: scheduledCount,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey<String>('admin-advertisements-search'),
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'ابحث بالعنوان أو الوجهة أو رابط الصورة',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _AdvertisementFilter.values
                  .map(
                    (filter) => Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.xs,
                      ),
                      child: ChoiceChip(
                        label: Text(_filterLabel(filter)),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<AdminAdvertisementPlacement?>(
            key: const ValueKey<String>(
              'admin-advertisements-placement-filter',
            ),
            initialValue: _placementFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'تصفية حسب موضع الظهور',
              prefixIcon: Icon(Icons.view_quilt_rounded),
            ),
            items: <DropdownMenuItem<AdminAdvertisementPlacement?>>[
              const DropdownMenuItem<AdminAdvertisementPlacement?>(
                value: null,
                child: Text('كل المواضع'),
              ),
              ...AdminAdvertisementPlacement.values.map(
                (placement) => DropdownMenuItem<AdminAdvertisementPlacement?>(
                  value: placement,
                  child: Text(
                    placement.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _placementFilter = value),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${visible.length} نتيجة',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (visible.isEmpty)
            const _AdvertisementEmptyView()
          else
            ...visible.map(
              (advertisement) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _AdvertisementCard(
                  advertisement: advertisement,
                  now: now,
                  onEdit: () => _openForm(advertisement),
                  onSetActive: (value) => _setActive(advertisement, value),
                  onDelete: () => _deleteAdvertisement(advertisement),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _filterLabel(_AdvertisementFilter filter) => switch (filter) {
        _AdvertisementFilter.all => 'الكل',
        _AdvertisementFilter.visible => 'ظاهر الآن',
        _AdvertisementFilter.scheduled => 'مجدول',
        _AdvertisementFilter.ended => 'منتهي',
        _AdvertisementFilter.inactive => 'متوقف',
      };
}

class _AdvertisementSummary extends StatelessWidget {
  const _AdvertisementSummary({
    required this.total,
    required this.visible,
    required this.scheduled,
  });

  final int total;
  final int visible;
  final int scheduled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryTeal, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إدارة الحملات الإعلانية',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'تحكم في المحتوى والوجهة والفترة وموضع الظهور من مكان واحد.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _SummaryPill(label: '$total إجمالي'),
              _SummaryPill(label: '$visible ظاهر الآن'),
              _SummaryPill(label: '$scheduled مجدول'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.white),
      ),
    );
  }
}

class _AdvertisementCard extends StatelessWidget {
  const _AdvertisementCard({
    required this.advertisement,
    required this.now,
    required this.onEdit,
    required this.onSetActive,
    required this.onDelete,
  });

  final AdminAdvertisementItem advertisement;
  final DateTime now;
  final VoidCallback onEdit;
  final ValueChanged<bool> onSetActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final state = advertisement.runtimeStateAt(now);
    final stateColor = switch (state) {
      AdminAdvertisementRuntimeState.visible => AppColors.success,
      AdminAdvertisementRuntimeState.scheduled => AppColors.warning,
      AdminAdvertisementRuntimeState.ended => AppColors.textMuted,
      AdminAdvertisementRuntimeState.inactive => AppColors.danger,
    };

    return Container(
      key: ValueKey<String>('admin-advertisement-card-${advertisement.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: AppColors.primaryTeal,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advertisement.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      advertisement.placement.shortLabel,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey<String>(
                  'admin-advertisement-actions-${advertisement.id}',
                ),
                tooltip: 'إجراءات الإعلان',
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'toggle') {
                    onSetActive(!advertisement.isActive);
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    key: ValueKey<String>(
                      'admin-advertisement-menu-edit-${advertisement.id}',
                    ),
                    value: 'edit',
                    child: const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_rounded),
                      title: Text('تعديل'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    key: ValueKey<String>(
                      'admin-advertisement-menu-toggle-${advertisement.id}',
                    ),
                    value: 'toggle',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        advertisement.isActive
                            ? Icons.pause_circle_rounded
                            : Icons.play_circle_fill_rounded,
                      ),
                      title: Text(
                        advertisement.isActive ? 'إيقاف' : 'تفعيل',
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    key: ValueKey<String>(
                      'admin-advertisement-menu-delete-${advertisement.id}',
                    ),
                    value: 'delete',
                    child: const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_forever_rounded,
                        color: AppColors.danger,
                      ),
                      title: Text(
                        'حذف نهائي',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _InfoChip(
                icon: Icons.visibility_rounded,
                label: state.label,
                color: stateColor,
              ),
              _InfoChip(
                icon: Icons.sort_rounded,
                label: 'ترتيب ${advertisement.sortOrder}',
                color: AppColors.primaryTeal,
              ),
              _InfoChip(
                icon: switch (advertisement.targetType) {
                  AdminAdvertisementTargetType.business =>
                    Icons.storefront_rounded,
                  AdminAdvertisementTargetType.external =>
                    Icons.open_in_new_rounded,
                  AdminAdvertisementTargetType.none =>
                    Icons.do_not_disturb_alt_rounded,
                },
                label: advertisement.targetLabel,
                color: AppColors.primaryDark,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailLine(
            icon: Icons.image_outlined,
            text: advertisement.imagePath,
          ),
          const SizedBox(height: AppSpacing.xs),
          _DetailLine(
            icon: Icons.schedule_rounded,
            text: _scheduleLabel(advertisement),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: ValueKey<String>(
                    'admin-advertisement-edit-${advertisement.id}',
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('تعديل'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.tonalIcon(
                  key: ValueKey<String>(
                    'admin-advertisement-toggle-${advertisement.id}',
                  ),
                  onPressed: () => onSetActive(!advertisement.isActive),
                  icon: Icon(
                    advertisement.isActive
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(advertisement.isActive ? 'إيقاف' : 'تفعيل'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _scheduleLabel(AdminAdvertisementItem item) {
    String format(DateTime value) {
      final local = value.toLocal();
      String two(int number) => number.toString().padLeft(2, '0');
      return '${local.year}/${two(local.month)}/${two(local.day)} '
          '${two(local.hour)}:${two(local.minute)}';
    }

    final start = item.startsAt == null ? 'بلا بداية' : format(item.startsAt!);
    final end = item.endsAt == null ? 'بلا نهاية' : format(item.endsAt!);
    return '$start ← $end';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: AppSpacing.xxs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _AdvertisementEmptyView extends StatelessWidget {
  const _AdvertisementEmptyView();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('admin-advertisements-empty'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.campaign_outlined,
            size: 52,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('لا توجد إعلانات مطابقة', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'غيّر البحث أو الفلاتر، أو أضف إعلانًا جديدًا.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AdvertisementStateView extends StatelessWidget {
  const _AdvertisementStateView({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
    required this.actionLabel,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onRetry, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
