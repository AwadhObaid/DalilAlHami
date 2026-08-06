import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/admin_content_repository.dart';
import '../../data/repositories/admin_repository.dart';
import '../../models/account_profile.dart';
import '../../models/admin_content_management.dart';
import '../../models/service_category.dart';
import 'admin_category_form_page.dart';

typedef AdminCategoriesLoader = Future<List<AdminCategoryItem>> Function();
typedef AdminCategoryActivationAction = Future<AdminContentMutationResult>
    Function(String categoryId, bool isActive);
typedef AdminCategoryDeleteAction = Future<AdminContentMutationResult> Function(
  String categoryId,
);

class AdminCategoryManagementPage extends StatefulWidget {
  const AdminCategoryManagementPage({
    super.key,
    this.profileLoader,
    this.categoriesLoader,
    this.saveAction,
    this.activationAction,
    this.deleteAction,
  });

  final Future<AccountProfile> Function()? profileLoader;
  final AdminCategoriesLoader? categoriesLoader;
  final AdminCategorySaveAction? saveAction;
  final AdminCategoryActivationAction? activationAction;
  final AdminCategoryDeleteAction? deleteAction;

  @override
  State<AdminCategoryManagementPage> createState() =>
      _AdminCategoryManagementPageState();
}

enum _CategoryPageState { loading, ready, denied, failed }

enum _CategoryFilter { all, active, archived }

class _AdminCategoryManagementPageState
    extends State<AdminCategoryManagementPage> {
  final AdminRepository _adminRepository = AdminRepository();
  final AdminContentRepository _contentRepository = AdminContentRepository();
  final TextEditingController _searchController = TextEditingController();

  _CategoryPageState _state = _CategoryPageState.loading;
  _CategoryFilter _filter = _CategoryFilter.all;
  List<AdminCategoryItem> _categories = const <AdminCategoryItem>[];
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
        _state = _CategoryPageState.loading;
        _message = null;
      });
    }
    try {
      final profile = await (widget.profileLoader?.call() ??
          _adminRepository.loadCurrentAdminProfile());
      if (!profile.isAdmin || !profile.isActive) {
        throw const AdminAccessDenied('لا تملك صلاحية إدارة الأقسام.');
      }
      final categories = await (widget.categoriesLoader?.call() ??
          _contentRepository.loadCategories());
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _state = _CategoryPageState.ready;
      });
    } on AdminAccessDenied catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _state = _CategoryPageState.denied;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _errorMessage(error);
        _state = _CategoryPageState.failed;
      });
    }
  }

  List<AdminCategoryItem> get _visibleCategories {
    final query = _normalize(_query);
    return _categories.where((category) {
      final matchesFilter = switch (_filter) {
        _CategoryFilter.active => !category.isArchived,
        _CategoryFilter.archived => category.isArchived,
        _CategoryFilter.all => true,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return _normalize(
        '${category.name} ${category.slug} ${category.groupLabel}',
      ).contains(query);
    }).toList(growable: false);
  }

  Future<void> _openForm([AdminCategoryItem? category]) async {
    final result = await Navigator.of(context).push<AdminContentMutationResult>(
      MaterialPageRoute<AdminContentMutationResult>(
        builder: (_) => AdminCategoryFormPage(
          initialCategory: category,
          onSave: widget.saveAction ?? _contentRepository.saveCategory,
        ),
      ),
    );
    if (!mounted || result == null) return;
    _showMessage(result.message);
    await _load();
  }

  Future<void> _toggleCategory(AdminCategoryItem category) async {
    final target = category.isArchived;
    if (!target && category.businessCount > 0) {
      _showMessage(
        'لا يمكن أرشفة قسم مرتبط بأنشطة. انقل الأنشطة أو احذفها أولًا.',
        error: true,
      );
      return;
    }
    final confirmed = await _confirm(
      title: target ? 'تفعيل القسم' : 'أرشفة القسم',
      message: target
          ? 'سيعود القسم للظهور في الدليل بعد المزامنة.'
          : 'سيختفي القسم من الدليل، ويمكن استعادته لاحقًا.',
      confirmLabel: target ? 'تفعيل' : 'أرشفة',
    );
    if (confirmed != true) return;
    try {
      final result =
          await (widget.activationAction?.call(category.id, target) ??
              _contentRepository.setCategoryActive(
                categoryId: category.id,
                isActive: target,
              ));
      if (!mounted) return;
      _showMessage(result.message);
      await _load();
    } catch (error) {
      _showMessage(_errorMessage(error), error: true);
    }
  }

  Future<void> _deleteCategory(AdminCategoryItem category) async {
    if (!category.canDeletePermanently) {
      _showMessage('لا يمكن حذف قسم مرتبط بأنشطة.', error: true);
      return;
    }
    final confirmed = await _confirm(
      title: 'حذف القسم نهائيًا',
      message: 'سيُحذف القسم نهائيًا ولن يمكن استعادته. هل أنت متأكد؟',
      confirmLabel: 'حذف نهائي',
      destructive: true,
    );
    if (confirmed != true) return;
    try {
      final result = await (widget.deleteAction?.call(category.id) ??
          _contentRepository.deleteCategory(category.id));
      if (!mounted) return;
      _showMessage(result.message);
      await _load();
    } catch (error) {
      _showMessage(_errorMessage(error), error: true);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
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
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('إدارة الأقسام')),
      floatingActionButton: _state == _CategoryPageState.ready
          ? FloatingActionButton.extended(
              key: const ValueKey<String>('admin-add-category-button'),
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('قسم جديد'),
            )
          : null,
      body: switch (_state) {
        _CategoryPageState.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        _CategoryPageState.denied => _StateMessage(
            key: const ValueKey<String>('admin-category-access-denied'),
            icon: Icons.lock_person_rounded,
            title: 'غير مصرح بالدخول',
            message: _message ?? 'لا تملك صلاحية إدارة الأقسام.',
            onRetry: () => Navigator.maybePop(context),
            actionLabel: 'العودة',
          ),
        _CategoryPageState.failed => _StateMessage(
            icon: Icons.cloud_off_rounded,
            title: 'تعذر تحميل الأقسام',
            message: _message ?? 'تحقق من الاتصال.',
            onRetry: _load,
            actionLabel: 'إعادة المحاولة',
          ),
        _CategoryPageState.ready => _buildReady(),
      },
    );
  }

  Widget _buildReady() {
    final visible = _visibleCategories;
    final activeCount = _categories.where((item) => !item.isArchived).length;
    final archivedCount = _categories.length - activeCount;
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        key: const PageStorageKey<String>('admin-category-management-list'),
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
              child: _CategoryHeader(
                total: _categories.length,
                active: activeCount,
                archived: archivedCount,
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
                key: const ValueKey<String>('admin-category-search-field'),
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم القسم أو المعرّف…',
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_CategoryFilter>(
                  segments: const [
                    ButtonSegment(
                      value: _CategoryFilter.all,
                      label: Text('الكل'),
                    ),
                    ButtonSegment(
                      value: _CategoryFilter.active,
                      label: Text('النشطة'),
                    ),
                    ButtonSegment(
                      value: _CategoryFilter.archived,
                      label: Text('المؤرشفة'),
                    ),
                  ],
                  selected: <_CategoryFilter>{_filter},
                  onSelectionChanged: (values) {
                    setState(() => _filter = values.first);
                  },
                ),
              ),
            ),
          ),
          if (visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyCategories(),
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
                  final category = visible[index];
                  return _CategoryCard(
                    key: ValueKey<String>('admin-category-${category.id}'),
                    category: category,
                    onEdit: () => _openForm(category),
                    onToggle: () => _toggleCategory(category),
                    onDelete: () => _deleteCategory(category),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.total,
    required this.active,
    required this.archived,
  });

  final int total;
  final int active;
  final int archived;

  @override
  Widget build(BuildContext context) {
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
            'هيكلة دليل الحامي',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '$total قسم • $active نشط • $archived مؤرشف',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    super.key,
  });

  final AdminCategoryItem category;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final archived = category.isArchived;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      archived ? AppColors.surfaceMuted : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  ServiceCategory.iconFromName(category.iconName),
                  color: archived ? AppColors.textMuted : AppColors.primaryTeal,
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
                            category.name,
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                        _StatusPill(archived: archived),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${category.slug} • ${category.groupLabel} • ترتيب ${category.sortOrder}',
                      textDirection: TextDirection.rtl,
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${category.businessCount} نشاط مرتبط • ${category.activeBusinessCount} منشور',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              TextButton.icon(
                key: ValueKey<String>('edit-category-${category.id}'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('تعديل'),
              ),
              const Spacer(),
              IconButton(
                tooltip: archived ? 'تفعيل' : 'أرشفة',
                onPressed: onToggle,
                icon: Icon(
                  archived ? Icons.restore_rounded : Icons.archive_rounded,
                ),
              ),
              IconButton(
                tooltip: 'حذف نهائي',
                onPressed: category.canDeletePermanently ? onDelete : null,
                color: AppColors.danger,
                icon: const Icon(Icons.delete_forever_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.archived});
  final bool archived;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: archived ? AppColors.surfaceMuted : AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        archived ? 'مؤرشف' : 'نشط',
        style: AppTextStyles.labelSmall.copyWith(
          color: archived ? AppColors.textSecondary : AppColors.success,
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
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
            Icon(icon, size: 54, color: AppColors.primaryTeal),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onRetry, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text('لا توجد أقسام مطابقة للبحث أو الفلتر.'),
      ),
    );
  }
}
