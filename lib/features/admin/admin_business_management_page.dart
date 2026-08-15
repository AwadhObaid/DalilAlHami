import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/admin_content_repository.dart';
import '../../data/repositories/admin_repository.dart';
import '../../models/account_profile.dart';
import '../../models/admin_content_management.dart';
import 'admin_business_form_page.dart';

typedef AdminBusinessesLoader = Future<List<AdminBusinessItem>> Function();
typedef AdminBusinessManagementActionCallback
    = Future<AdminContentMutationResult> Function(
  String businessId,
  AdminBusinessManagementAction action,
  String? reason,
);
typedef AdminBusinessDeleteAction = Future<AdminContentMutationResult> Function(
  String businessId,
);

class AdminBusinessManagementPage extends StatefulWidget {
  const AdminBusinessManagementPage({
    super.key,
    this.profileLoader,
    this.businessesLoader,
    this.categoriesLoader,
    this.saveAction,
    this.managementAction,
    this.deleteAction,
  });

  final Future<AccountProfile> Function()? profileLoader;
  final AdminBusinessesLoader? businessesLoader;
  final Future<List<AdminCategoryItem>> Function()? categoriesLoader;
  final AdminBusinessSaveAction? saveAction;
  final AdminBusinessManagementActionCallback? managementAction;
  final AdminBusinessDeleteAction? deleteAction;

  @override
  State<AdminBusinessManagementPage> createState() =>
      _AdminBusinessManagementPageState();
}

enum _BusinessPageState { loading, ready, denied, failed }

enum _BusinessFilter {
  all,
  approved,
  pending,
  changesRequested,
  rejected,
  suspended,
  draft,
}

class _AdminBusinessManagementPageState
    extends State<AdminBusinessManagementPage> {
  final AdminRepository _adminRepository = AdminRepository();
  final AdminContentRepository _contentRepository = AdminContentRepository();
  final TextEditingController _searchController = TextEditingController();

  _BusinessPageState _state = _BusinessPageState.loading;
  _BusinessFilter _filter = _BusinessFilter.all;
  List<AdminBusinessItem> _businesses = const <AdminBusinessItem>[];
  List<AdminCategoryItem> _categories = const <AdminCategoryItem>[];
  String _query = '';
  String? _categoryFilter;
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
        _state = _BusinessPageState.loading;
        _message = null;
      });
    }
    try {
      final profile = await (widget.profileLoader?.call() ??
          _adminRepository.loadCurrentAdminProfile());
      if (!profile.isAdmin || !profile.isActive) {
        throw const AdminAccessDenied('لا تملك صلاحية إدارة الأنشطة.');
      }
      final results = await Future.wait<Object>([
        widget.businessesLoader?.call() ?? _contentRepository.loadBusinesses(),
        widget.categoriesLoader?.call() ?? _contentRepository.loadCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _businesses = results[0] as List<AdminBusinessItem>;
        _categories = results[1] as List<AdminCategoryItem>;
        _state = _BusinessPageState.ready;
      });
    } on AdminAccessDenied catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _state = _BusinessPageState.denied;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _errorMessage(error);
        _state = _BusinessPageState.failed;
      });
    }
  }

  List<AdminBusinessItem> get _visibleBusinesses {
    final query = _normalize(_query);
    final requiredStatus = switch (_filter) {
      _BusinessFilter.approved => 'approved',
      _BusinessFilter.pending => 'pending',
      _BusinessFilter.changesRequested => 'changes_requested',
      _BusinessFilter.rejected => 'rejected',
      _BusinessFilter.suspended => 'suspended',
      _BusinessFilter.draft => 'draft',
      _BusinessFilter.all => null,
    };

    return _businesses.where((business) {
      if (requiredStatus != null && business.status != requiredStatus) {
        return false;
      }
      if (_categoryFilter != null && business.categoryId != _categoryFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return _normalize(
        '${business.name} ${business.categoryName} ${business.displayOwner} '
        '${business.contactSearchText} ${business.address}',
      ).contains(query);
    }).toList(growable: false);
  }

  Future<void> _openForm([AdminBusinessItem? business]) async {
    if (_categories.where((category) => !category.isArchived).isEmpty) {
      _showMessage('أضف قسمًا نشطًا قبل إضافة نشاط.', error: true);
      return;
    }
    final result = await Navigator.of(context).push<AdminContentMutationResult>(
      MaterialPageRoute<AdminContentMutationResult>(
        builder: (_) => AdminBusinessFormPage(
          categories: _categories,
          initialBusiness: business,
          onSave: widget.saveAction ?? _contentRepository.saveBusiness,
        ),
      ),
    );
    if (!mounted || result == null) return;
    _showMessage(result.message);
    await _load();
  }

  Future<void> _runAction(
    AdminBusinessItem business,
    AdminBusinessManagementAction action,
  ) async {
    String? reason;
    if (action.requiresReason) {
      reason = await _askReason();
      if (reason == null) return;
    } else {
      final confirmed = await _confirmAction(business, action);
      if (confirmed != true) return;
    }

    try {
      final result = await (widget.managementAction?.call(
            business.id,
            action,
            reason,
          ) ??
          _contentRepository.manageBusiness(
            businessId: business.id,
            action: action,
            reason: reason,
          ));
      if (!mounted) return;
      _showMessage(result.message);
      await _load();
    } catch (error) {
      _showMessage(_errorMessage(error), error: true);
    }
  }

  Future<void> _deleteBusiness(AdminBusinessItem business) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف النشاط نهائيًا'),
        content: Text(
          'سيُحذف «${business.name}» وصوره وسجل مراجعته وارتباطاته نهائيًا. '
          'سيصل الحذف إلى الأجهزة عبر المزامنة. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await (widget.deleteAction?.call(business.id) ??
          _contentRepository.deleteBusiness(business.id));
      if (!mounted) return;
      _showMessage(result.message);
      await _load();
    } catch (error) {
      _showMessage(_errorMessage(error), error: true);
    }
  }

  Future<bool?> _confirmAction(
    AdminBusinessItem business,
    AdminBusinessManagementAction action,
  ) {
    final data = switch (action) {
      AdminBusinessManagementAction.feature => (
          'تمييز النشاط',
          'سيظهر «${business.name}» ضمن الأنشطة المميزة.',
          'تمييز',
        ),
      AdminBusinessManagementAction.unfeature => (
          'إلغاء التمييز',
          'سيُزال النشاط من قائمة الأنشطة المميزة.',
          'إلغاء التمييز',
        ),
      AdminBusinessManagementAction.restore => (
          'استعادة النشاط',
          'سيعود النشاط إلى حالة معتمد ويظهر في الدليل.',
          'استعادة',
        ),
      AdminBusinessManagementAction.suspend => (
          'إيقاف النشاط',
          'اكتب سبب الإيقاف.',
          'إيقاف',
        ),
    };
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(data.$1),
        content: Text(data.$2),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(data.$3),
          ),
        ],
      ),
    );
  }

  Future<String?> _askReason() {
    return showDialog<String>(
      context: context,
      builder: (_) => const _SuspensionReasonDialog(),
    );
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
    AppColors.bindToTheme(context);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('إدارة الأنشطة')),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _state == _BusinessPageState.ready
          ? FloatingActionButton.extended(
              key: const ValueKey<String>('admin-add-business-button'),
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('نشاط جديد'),
            )
          : null,
      body: switch (_state) {
        _BusinessPageState.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        _BusinessPageState.denied => _BusinessStateMessage(
            key: const ValueKey<String>('admin-business-access-denied'),
            icon: Icons.lock_person_rounded,
            title: 'غير مصرح بالدخول',
            message: _message ?? 'لا تملك صلاحية إدارة الأنشطة.',
            actionLabel: 'العودة',
            onAction: () => Navigator.maybePop(context),
          ),
        _BusinessPageState.failed => _BusinessStateMessage(
            icon: Icons.cloud_off_rounded,
            title: 'تعذر تحميل الأنشطة',
            message: _message ?? 'تحقق من الاتصال.',
            actionLabel: 'إعادة المحاولة',
            onAction: _load,
          ),
        _BusinessPageState.ready => _buildReady(),
      },
    );
  }

  Widget _buildReady() {
    final visible = _visibleBusinesses;
    final approved = _businesses.where((item) => item.isApproved).length;
    final pending = _businesses.where((item) => item.isPending).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        key: const PageStorageKey<String>('admin-business-management-list'),
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
              child: _BusinessHeader(
                total: _businesses.length,
                approved: approved,
                pending: pending,
              ),
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
                key: const ValueKey<String>('admin-business-search-field'),
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: AppLocaleText.runtime(
                      'ابحث بالنشاط أو المالك أو الهاتف…'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
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
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: _BusinessFilter.values
                    .map(
                      (filter) => ChoiceChip(
                        label: Text(_filterLabel(filter)),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    )
                    .toList(growable: false),
              ),
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
              child: DropdownButtonFormField<String>(
                key: const ValueKey<String>('admin-business-category-filter'),
                initialValue: _categoryFilter ?? '',
                decoration: InputDecoration(
                  labelText: AppLocaleText.runtime('تصفية حسب القسم'),
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('جميع الأقسام'),
                  ),
                  ..._categories.map(
                    (category) => DropdownMenuItem<String>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(
                  () => _categoryFilter =
                      value == null || value.isEmpty ? null : value,
                ),
              ),
            ),
          ),
          if (visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child:
                  Center(child: Text('لا توجد أنشطة مطابقة للبحث أو الفلتر.')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                110,
              ),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final business = visible[index];
                  return _BusinessCard(
                    key: ValueKey<String>('admin-business-${business.id}'),
                    business: business,
                    onEdit: () => _openForm(business),
                    onAction: (action) => _runAction(business, action),
                    onDelete: () => _deleteBusiness(business),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _filterLabel(_BusinessFilter filter) {
    return switch (filter) {
      _BusinessFilter.all => 'الكل',
      _BusinessFilter.approved => 'معتمد',
      _BusinessFilter.pending => 'معلّق',
      _BusinessFilter.changesRequested => 'يحتاج تعديل',
      _BusinessFilter.rejected => 'مرفوض',
      _BusinessFilter.suspended => 'موقوف',
      _BusinessFilter.draft => 'مسودة',
    };
  }
}

class _BusinessHeader extends StatelessWidget {
  const _BusinessHeader({
    required this.total,
    required this.approved,
    required this.pending,
  });

  final int total;
  final int approved;
  final int pending;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDeep, AppColors.primaryTeal],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'محتوى الأنشطة',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '$total نشاط • $approved معتمد • $pending بانتظار المراجعة',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.business,
    required this.onEdit,
    required this.onAction,
    required this.onDelete,
    super.key,
  });

  final AdminBusinessItem business;
  final VoidCallback onEdit;
  final Future<void> Function(AdminBusinessManagementAction action) onAction;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.subtle,
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
                child: Icon(
                  business.isFeatured
                      ? Icons.workspace_premium_rounded
                      : Icons.storefront_rounded,
                  color: business.isFeatured
                      ? AppColors.advertisementGold
                      : AppColors.primaryTeal,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            business.name,
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                        _BusinessStatusPill(status: business.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${business.categoryName} • ${business.displayOwner}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${business.phoneContact} • ${business.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (business.rejectionReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                business.rejectionReason!,
                style: AppTextStyles.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              TextButton.icon(
                key: ValueKey<String>('edit-business-${business.id}'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('تعديل'),
              ),
              const Spacer(),
              PopupMenuButton<_BusinessMenuAction>(
                key: ValueKey<String>('business-actions-${business.id}'),
                tooltip: AppLocaleText.runtime('إجراءات النشاط'),
                onSelected: (action) async {
                  switch (action) {
                    case _BusinessMenuAction.feature:
                      await onAction(AdminBusinessManagementAction.feature);
                      break;
                    case _BusinessMenuAction.unfeature:
                      await onAction(AdminBusinessManagementAction.unfeature);
                      break;
                    case _BusinessMenuAction.suspend:
                      await onAction(AdminBusinessManagementAction.suspend);
                      break;
                    case _BusinessMenuAction.restore:
                      await onAction(AdminBusinessManagementAction.restore);
                      break;
                    case _BusinessMenuAction.delete:
                      await onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (business.canBeFeatured && !business.isFeatured)
                    const PopupMenuItem(
                      value: _BusinessMenuAction.feature,
                      child: Text('تمييز النشاط'),
                    ),
                  if (business.isFeatured)
                    const PopupMenuItem(
                      value: _BusinessMenuAction.unfeature,
                      child: Text('إلغاء التمييز'),
                    ),
                  if (business.isApproved)
                    PopupMenuItem(
                      key: ValueKey<String>(
                        'business-menu-suspend-${business.id}',
                      ),
                      value: _BusinessMenuAction.suspend,
                      child: const Text('إيقاف النشاط'),
                    ),
                  if (business.isSuspended)
                    const PopupMenuItem(
                      value: _BusinessMenuAction.restore,
                      child: Text('استعادة النشاط'),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: _BusinessMenuAction.delete,
                    child: Text(
                      'حذف نهائي',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _BusinessMenuAction { feature, unfeature, suspend, restore, delete }

class _BusinessStatusPill extends StatelessWidget {
  const _BusinessStatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final data = switch (status) {
      'approved' => (AppColors.mintSoft, AppColors.success),
      'pending' => (AppColors.warningSoft, AppColors.warning),
      'rejected' => (AppColors.dangerSoft, AppColors.danger),
      'changes_requested' => (AppColors.warningSoft, AppColors.warning),
      'suspended' => (AppColors.surfaceMuted, AppColors.textSecondary),
      _ => (AppColors.categoryBlueSoft, AppColors.primaryDark),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: data.$1,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        adminBusinessStatusLabel(status),
        style: AppTextStyles.labelSmall.copyWith(color: data.$2),
      ),
    );
  }
}

class _BusinessStateMessage extends StatelessWidget {
  const _BusinessStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: AppColors.primaryTeal),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _SuspensionReasonDialog extends StatefulWidget {
  const _SuspensionReasonDialog();

  @override
  State<_SuspensionReasonDialog> createState() =>
      _SuspensionReasonDialogState();
}

class _SuspensionReasonDialogState extends State<_SuspensionReasonDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _valid = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.length < 5) return;
    _focusNode.unfocus();
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return AlertDialog(
      key: const ValueKey<String>('admin-business-suspension-dialog'),
      title: const Text('سبب إيقاف النشاط'),
      content: TextField(
        key: const ValueKey<String>('admin-business-suspension-reason'),
        controller: _controller,
        focusNode: _focusNode,
        minLines: 3,
        maxLines: 5,
        autofocus: true,
        onChanged: (value) {
          final valid = value.trim().length >= 5;
          if (valid != _valid) setState(() => _valid = valid);
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText:
              AppLocaleText.runtime('اكتب سببًا واضحًا لا يقل عن خمسة أحرف…'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _focusNode.unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const ValueKey<String>(
            'admin-business-suspension-confirm',
          ),
          onPressed: _valid ? _submit : null,
          child: const Text('إيقاف النشاط'),
        ),
      ],
    );
  }
}
