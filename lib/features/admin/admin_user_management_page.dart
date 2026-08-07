import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/admin_user_repository.dart';
import '../../models/account_profile.dart';
import '../../models/admin_user_management.dart';
import '../shared/widgets/cached_directory_image.dart';

typedef AdminUsersLoader = Future<AdminUserPage> Function({
  String query,
  String status,
  String role,
  int page,
  int perPage,
});
typedef AdminUserDetailLoader = Future<AdminManagedUserDetail> Function(
  String userId,
);
typedef AdminUserStatusExecutor = Future<AdminUserActionResult> Function({
  required String userId,
  required bool isActive,
  String? reason,
});
typedef AdminUserRoleExecutor = Future<AdminUserActionResult> Function({
  required String userId,
  required String role,
});
typedef AdminUserDeleteExecutor = Future<AdminUserActionResult> Function({
  required String userId,
  required bool isDeleted,
  String? reason,
});

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({
    super.key,
    this.profileLoader,
    this.usersLoader,
    this.detailLoader,
    this.statusExecutor,
    this.roleExecutor,
    this.deleteExecutor,
  });

  final Future<AccountProfile> Function()? profileLoader;
  final AdminUsersLoader? usersLoader;
  final AdminUserDetailLoader? detailLoader;
  final AdminUserStatusExecutor? statusExecutor;
  final AdminUserRoleExecutor? roleExecutor;
  final AdminUserDeleteExecutor? deleteExecutor;

  @override
  State<AdminUserManagementPage> createState() =>
      _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> {
  final AdminUserRepository _repository = AdminUserRepository();
  final TextEditingController _searchController = TextEditingController();

  AccountProfile? _adminProfile;
  AdminUserPage? _pageData;
  String _status = 'all';
  String _role = 'all';
  int _page = 1;
  bool _isLoading = true;
  bool _isActing = false;
  String? _errorMessage;

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

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) {
      _page = 1;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await (widget.profileLoader?.call() ??
          _repository.loadCurrentAdminProfile());
      if (!profile.isAdmin || !profile.isActive) {
        throw const AdminAccessDenied(
          'هذا الحساب لا يملك صلاحية إدارة المستخدمين.',
        );
      }

      final loader = widget.usersLoader ?? _repository.loadUsers;
      final pageData = await loader(
        query: _searchController.text,
        status: _status,
        role: _role,
        page: _page,
        perPage: 20,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _adminProfile = profile;
        _pageData = pageData;
        _page = pageData.page;
        _isLoading = false;
      });
    } on AdminAccessDenied catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } on AdminUserRepositoryFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage =
            'تعذر تحميل المستخدمين. تحقق من الاتصال ثم أعد المحاولة.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openDetails(AdminManagedUser user) async {
    final loader = widget.detailLoader ?? _repository.loadUserDetail;
    final detailFuture = loader(user.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FutureBuilder<AdminManagedUserDetail>(
          future: detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _DetailErrorView(
                message: snapshot.error is AdminUserRepositoryFailure
                    ? (snapshot.error! as AdminUserRepositoryFailure).message
                    : 'تعذر تحميل تفاصيل المستخدم.',
              );
            }
            final detail = snapshot.data!;
            return _UserDetailSheet(
              detail: detail,
              isActing: _isActing,
              onStatus: () async {
                Navigator.pop(sheetContext);
                await _confirmStatusChange(detail.user);
              },
              onRole: () async {
                Navigator.pop(sheetContext);
                await _confirmRoleChange(detail.user);
              },
              onDelete: () async {
                Navigator.pop(sheetContext);
                await _confirmDeleteChange(detail.user);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _confirmStatusChange(AdminManagedUser user) async {
    if (user.isCurrentUser || user.isDeleted || _isActing) {
      return;
    }

    final targetActive = !user.isActive;
    String? reason;

    if (targetActive) {
      final confirmed = await _showSimpleConfirmation(
        title: 'تفعيل الحساب',
        message: 'سيتم السماح للمستخدم بتسجيل الدخول واستخدام حسابه مجددًا.',
        confirmLabel: 'تفعيل',
        confirmKey: 'admin-user-status-confirm',
      );
      if (!confirmed) {
        return;
      }
    } else {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => _AdminUserReasonDialog(
          title: 'إيقاف الحساب',
          message:
              'سيُمنع المستخدم من تجديد الجلسة وتعديل بياناته حتى إعادة التفعيل.',
          fieldKey: 'admin-user-suspension-reason',
          confirmKey: 'admin-user-status-confirm',
          cancelKey: 'admin-user-suspension-reason-cancel',
          labelText: AppLocaleText.runtime('سبب الإيقاف'),
          confirmLabel: 'إيقاف',
        ),
      );
      if (reason == null) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    await _runAction(() {
      final executor = widget.statusExecutor ?? _repository.setUserActive;
      return executor(
        userId: user.id,
        isActive: targetActive,
        reason: reason,
      );
    });
  }

  Future<void> _confirmRoleChange(AdminManagedUser user) async {
    if (user.isCurrentUser || user.isDeleted || _isActing) {
      return;
    }

    final targetRole = user.isAdmin ? 'user' : 'admin';
    final confirmed = await _showSimpleConfirmation(
      title: user.isAdmin ? 'إلغاء صلاحية المدير' : 'منح صلاحية مدير',
      message: user.isAdmin
          ? 'سيصبح الحساب مستخدمًا عاديًا ولن يتمكن من فتح لوحة الإدارة.'
          : 'سيتمكن الحساب من إدارة المستخدمين والمحتوى والأنشطة.',
      confirmLabel: 'تأكيد',
      confirmKey: 'admin-user-role-confirm',
    );
    if (!confirmed || !mounted) {
      return;
    }

    await _runAction(() {
      final executor = widget.roleExecutor ?? _repository.setUserRole;
      return executor(userId: user.id, role: targetRole);
    });
  }

  Future<void> _confirmDeleteChange(AdminManagedUser user) async {
    if (user.isCurrentUser || _isActing) {
      return;
    }

    final targetDeleted = !user.isDeleted;
    String? reason;

    if (targetDeleted) {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => _AdminUserReasonDialog(
          title: 'حذف الحساب ظاهريًا',
          message:
              'سيُخفى الحساب من الاستخدام ويُمنع تسجيل الدخول، من دون حذف بيانات المصادقة أو الأنشطة نهائيًا.',
          fieldKey: 'admin-user-delete-reason',
          confirmKey: 'admin-user-delete-confirm',
          cancelKey: 'admin-user-delete-reason-cancel',
          labelText: AppLocaleText.runtime('سبب الحذف الظاهري'),
          confirmLabel: 'حذف ظاهري',
        ),
      );
      if (reason == null) {
        return;
      }
    } else {
      final confirmed = await _showSimpleConfirmation(
        title: 'استعادة الحساب',
        message: 'سيُعاد تفعيل الحساب والسماح للمستخدم بتسجيل الدخول مجددًا.',
        confirmLabel: 'استعادة',
        confirmKey: 'admin-user-delete-confirm',
      );
      if (!confirmed) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    await _runAction(() {
      final executor = widget.deleteExecutor ?? _repository.setUserDeleted;
      return executor(
        userId: user.id,
        isDeleted: targetDeleted,
        reason: reason,
      );
    });
  }

  Future<bool> _showSimpleConfirmation({
    required String title,
    required String message,
    required String confirmLabel,
    required String confirmKey,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              key: ValueKey<String>(confirmKey),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _runAction(
    Future<AdminUserActionResult> Function() action,
  ) async {
    setState(() => _isActing = true);
    try {
      final result = await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result.message)));
      await _load();
    } on AdminUserRepositoryFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isActing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        actions: [
          IconButton(
            tooltip: AppLocaleText.runtime('تحديث'),
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _pageData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _pageData == null) {
      return _UserStateView(message: _errorMessage!, onRetry: _load);
    }

    final pageData = _pageData!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const PageStorageKey<String>('admin-user-management-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          _UserSummary(pageData: pageData),
          const SizedBox(height: AppSpacing.md),
          _UserFilters(
            searchController: _searchController,
            status: _status,
            role: _role,
            onStatusChanged: (value) {
              setState(() => _status = value);
              _load(resetPage: true);
            },
            onRoleChanged: (value) {
              setState(() => _role = value);
              _load(resetPage: true);
            },
            onSearch: () => _load(resetPage: true),
            onClear: () {
              _searchController.clear();
              _load(resetPage: true);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (pageData.users.isEmpty)
            const _EmptyUsersView()
          else
            ...pageData.users.map(
              (user) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _UserCard(
                  user: user,
                  isActing: _isActing,
                  onOpen: () => _openDetails(user),
                  onStatus: () => _confirmStatusChange(user),
                  onRole: () => _confirmRoleChange(user),
                  onDelete: () => _confirmDeleteChange(user),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          _PaginationBar(
            page: pageData.page,
            totalPages: pageData.totalPages,
            hasPrevious: pageData.hasPrevious,
            hasNext: pageData.hasNext,
            onPrevious: () {
              setState(() => _page -= 1);
              _load();
            },
            onNext: () {
              setState(() => _page += 1);
              _load();
            },
          ),
          if (_adminProfile != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'الحساب الحالي: ${_adminProfile!.fullName}',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminUserReasonDialog extends StatefulWidget {
  const _AdminUserReasonDialog({
    required this.title,
    required this.message,
    required this.fieldKey,
    required this.confirmKey,
    required this.cancelKey,
    required this.labelText,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String fieldKey;
  final String confirmKey;
  final String cancelKey;
  final String labelText;
  final String confirmLabel;

  @override
  State<_AdminUserReasonDialog> createState() => _AdminUserReasonDialogState();
}

class _AdminUserReasonDialogState extends State<_AdminUserReasonDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _validationMessage;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _cancel() {
    if (_isClosing) {
      return;
    }
    setState(() => _isClosing = true);
    _focusNode.unfocus();
    Navigator.of(context).pop();
  }

  void _submit() {
    if (_isClosing) {
      return;
    }

    final reason = _controller.text.trim();
    if (reason.length < 5) {
      setState(() {
        _validationMessage = 'اكتب سببًا واضحًا لا يقل عن خمسة أحرف.';
      });
      return;
    }

    setState(() {
      _isClosing = true;
      _validationMessage = null;
    });
    _focusNode.unfocus();
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: ValueKey<String>(widget.fieldKey),
              controller: _controller,
              focusNode: _focusNode,
              enabled: !_isClosing,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              onChanged: (_) {
                if (_validationMessage != null) {
                  setState(() => _validationMessage = null);
                }
              },
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: AppLocaleText.runtime(
                    'اكتب سببًا واضحًا لا يقل عن خمسة أحرف'),
                errorText: _validationMessage,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: ValueKey<String>(widget.cancelKey),
          onPressed: _isClosing ? null : _cancel,
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: ValueKey<String>(widget.confirmKey),
          onPressed: _isClosing ? null : _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _UserSummary extends StatelessWidget {
  const _UserSummary({required this.pageData});

  final AdminUserPage pageData;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      key: const ValueKey<String>('admin-user-summary'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDeep, AppColors.primaryTeal],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${pageData.total} حساب',
            style:
                AppTextStyles.headlineMedium.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _SummaryPill(label: '${pageData.activeCount} نشط'),
              _SummaryPill(label: '${pageData.suspendedCount} موقوف'),
              _SummaryPill(label: '${pageData.deletedCount} محذوف ظاهريًا'),
              _SummaryPill(label: '${pageData.adminCount} مدير'),
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
    AppColors.bindToTheme(context);
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

class _UserFilters extends StatelessWidget {
  const _UserFilters({
    required this.searchController,
    required this.status,
    required this.role,
    required this.onStatusChanged,
    required this.onRoleChanged,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String status;
  final String role;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          TextField(
            key: const ValueKey<String>('admin-user-search-field'),
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              labelText:
                  AppLocaleText.runtime('البحث بالاسم أو البريد أو الهاتف'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: AppLocaleText.runtime('مسح البحث'),
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final statusField = DropdownButtonFormField<String>(
                key: const ValueKey<String>('admin-user-status-filter'),
                initialValue: status,
                isExpanded: true,
                decoration:
                    InputDecoration(labelText: AppLocaleText.runtime('الحالة')),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                  DropdownMenuItem(value: 'active', child: Text('نشط')),
                  DropdownMenuItem(value: 'suspended', child: Text('موقوف')),
                  DropdownMenuItem(
                    value: 'deleted',
                    child: Text('محذوف ظاهريًا'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onStatusChanged(value);
                  }
                },
              );
              final roleField = DropdownButtonFormField<String>(
                key: const ValueKey<String>('admin-user-role-filter'),
                initialValue: role,
                isExpanded: true,
                decoration:
                    InputDecoration(labelText: AppLocaleText.runtime('الدور')),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                  DropdownMenuItem(value: 'user', child: Text('مستخدم')),
                  DropdownMenuItem(value: 'admin', child: Text('مدير')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onRoleChanged(value);
                  }
                },
              );

              if (constraints.maxWidth < 520) {
                return Column(
                  children: [
                    statusField,
                    const SizedBox(height: AppSpacing.sm),
                    roleField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: statusField),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: roleField),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey<String>('admin-user-search-action'),
              onPressed: onSearch,
              icon: const Icon(Icons.manage_search_rounded),
              label: const Text('تطبيق البحث'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isActing,
    required this.onOpen,
    required this.onStatus,
    required this.onRole,
    required this.onDelete,
  });

  final AdminManagedUser user;
  final bool isActing;
  final VoidCallback onOpen;
  final VoidCallback onStatus;
  final VoidCallback onRole;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final statusColor = user.isDeleted
        ? AppColors.textMuted
        : user.isActive
            ? AppColors.success
            : AppColors.danger;
    return Container(
      key: ValueKey<String>('admin-user-card-${user.id}'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: CachedDirectoryImage(
                  source: user.avatarUrl,
                  bucket: 'avatars',
                  width: 54,
                  height: 54,
                  memCacheWidth: 108,
                  memCacheHeight: 108,
                  placeholder: _AvatarFallback(name: user.displayName),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      user.email.isEmpty ? 'لا يوجد بريد مسجل' : user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              if (user.isCurrentUser)
                const Tooltip(
                  message: 'الحساب الحالي',
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.primaryTeal,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _UserChip(
                label: user.statusLabel,
                color: statusColor,
                icon: user.isDeleted
                    ? Icons.delete_outline_rounded
                    : user.isActive
                        ? Icons.check_circle_outline_rounded
                        : Icons.block_rounded,
              ),
              _UserChip(
                label: user.roleLabel,
                color: user.isAdmin ? AppColors.warning : AppColors.primaryTeal,
                icon: user.isAdmin
                    ? Icons.admin_panel_settings_rounded
                    : Icons.person_outline_rounded,
              ),
              _UserChip(
                label: '${user.businessCount} نشاط',
                color: AppColors.primaryDark,
                icon: Icons.storefront_rounded,
              ),
            ],
          ),
          if (user.suspensionReason?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${user.isDeleted ? 'سبب الحذف الظاهري' : 'سبب الإيقاف'}: '
              '${user.suspensionReason}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('التفاصيل'),
              ),
              OutlinedButton.icon(
                key: ValueKey<String>('admin-user-status-${user.id}'),
                onPressed: user.isCurrentUser || user.isDeleted || isActing
                    ? null
                    : onStatus,
                icon: Icon(
                  user.isActive ? Icons.block_rounded : Icons.restore_rounded,
                ),
                label: Text(user.isActive ? 'إيقاف' : 'تفعيل'),
              ),
              OutlinedButton.icon(
                key: ValueKey<String>('admin-user-role-${user.id}'),
                onPressed: user.isCurrentUser || user.isDeleted || isActing
                    ? null
                    : onRole,
                icon: Icon(
                  user.isAdmin
                      ? Icons.person_remove_alt_1_rounded
                      : Icons.admin_panel_settings_rounded,
                ),
                label: Text(user.isAdmin ? 'إلغاء الإدارة' : 'تعيين مدير'),
              ),
              OutlinedButton.icon(
                key: ValueKey<String>('admin-user-delete-${user.id}'),
                onPressed: user.isCurrentUser || isActing ? null : onDelete,
                icon: Icon(
                  user.isDeleted
                      ? Icons.restore_from_trash_rounded
                      : Icons.delete_outline_rounded,
                ),
                label: Text(user.isDeleted ? 'استعادة' : 'حذف ظاهري'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final value = name.trim();
    return ColoredBox(
      color: AppColors.primarySoft,
      child: Center(
        child: Text(
          value.isEmpty ? 'م' : value.substring(0, 1),
          style:
              AppTextStyles.titleLarge.copyWith(color: AppColors.primaryTeal),
        ),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

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
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey<String>('admin-users-previous-page'),
            onPressed: hasPrevious ? onPrevious : null,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('السابق'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('$page من $totalPages', style: AppTextStyles.labelMedium),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey<String>('admin-users-next-page'),
            onPressed: hasNext ? onNext : null,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('التالي'),
          ),
        ),
      ],
    );
  }
}

class _UserDetailSheet extends StatelessWidget {
  const _UserDetailSheet({
    required this.detail,
    required this.isActing,
    required this.onStatus,
    required this.onRole,
    required this.onDelete,
  });

  final AdminManagedUserDetail detail;
  final bool isActing;
  final VoidCallback onStatus;
  final VoidCallback onRole;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final user = detail.user;
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return ListView(
            key: const PageStorageKey<String>('admin-user-detail-list'),
            controller: controller,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              Text(user.displayName, style: AppTextStyles.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(user.email, style: AppTextStyles.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _UserChip(
                    label: user.statusLabel,
                    color: user.isDeleted
                        ? AppColors.textMuted
                        : user.isActive
                            ? AppColors.success
                            : AppColors.danger,
                    icon: user.isDeleted
                        ? Icons.delete_outline_rounded
                        : user.isActive
                            ? Icons.check_circle_outline_rounded
                            : Icons.block_rounded,
                  ),
                  _UserChip(
                    label: user.roleLabel,
                    color: user.isAdmin
                        ? AppColors.warning
                        : AppColors.primaryTeal,
                    icon: user.isAdmin
                        ? Icons.admin_panel_settings_rounded
                        : Icons.person_outline_rounded,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailRow(label: 'الهاتف', value: user.phone),
              _DetailRow(
                label: 'طرق الدخول',
                value: user.providers.isEmpty
                    ? 'غير معروفة'
                    : user.providers.join('، '),
              ),
              _DetailRow(
                label: 'تاريخ التسجيل',
                value: _formatDate(user.createdAt),
              ),
              _DetailRow(
                label: 'آخر تسجيل دخول',
                value: _formatDate(user.lastSignInAt),
              ),
              const SizedBox(height: AppSpacing.md),
              if (!user.isCurrentUser)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.icon(
                      onPressed: isActing || user.isDeleted ? null : onStatus,
                      icon: Icon(
                        user.isActive
                            ? Icons.block_rounded
                            : Icons.restore_rounded,
                      ),
                      label:
                          Text(user.isActive ? 'إيقاف الحساب' : 'تفعيل الحساب'),
                    ),
                    OutlinedButton.icon(
                      onPressed: isActing || user.isDeleted ? null : onRole,
                      icon: const Icon(Icons.admin_panel_settings_rounded),
                      label:
                          Text(user.isAdmin ? 'إلغاء الإدارة' : 'تعيين مدير'),
                    ),
                    OutlinedButton.icon(
                      onPressed: isActing ? null : onDelete,
                      icon: Icon(
                        user.isDeleted
                            ? Icons.restore_from_trash_rounded
                            : Icons.delete_outline_rounded,
                      ),
                      label: Text(
                        user.isDeleted ? 'استعادة الحساب' : 'حذف ظاهري',
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),
              Text('الأنشطة المرتبطة', style: AppTextStyles.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              if (detail.businesses.isEmpty)
                const Text('لا توجد أنشطة مرتبطة بهذا الحساب.')
              else
                ...detail.businesses.map(
                  (business) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storefront_rounded),
                    title: Text(business.name),
                    subtitle: Text(business.status),
                    trailing: Icon(
                      business.isActive
                          ? Icons.check_circle_outline_rounded
                          : Icons.block_rounded,
                      color: business.isActive
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text('سجل الإجراءات', style: AppTextStyles.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              if (detail.auditEntries.isEmpty)
                const Text('لا توجد إجراءات إدارية مسجلة لهذا المستخدم.')
              else
                ...detail.auditEntries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded),
                    title: Text(entry.actionLabel),
                    subtitle: Text(
                      '${entry.actorName} — ${entry.reason.isEmpty ? 'بدون ملاحظة' : entry.reason}',
                    ),
                    trailing: Text(
                      _formatDate(entry.createdAt),
                      style: AppTextStyles.labelSmall,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label, style: AppTextStyles.labelMedium),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? 'غير متوفر' : value,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailErrorView extends StatelessWidget {
  const _DetailErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return SizedBox(
      height: 300,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _EmptyUsersView extends StatelessWidget {
  const _EmptyUsersView();

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(Icons.person_search_rounded,
              size: 54, color: AppColors.textMuted),
          SizedBox(height: AppSpacing.sm),
          Text('لا توجد حسابات مطابقة للبحث.'),
        ],
      ),
    );
  }
}

class _UserStateView extends StatelessWidget {
  const _UserStateView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.manage_accounts_rounded, size: 56),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return AppLocaleText.runtime('غير متوفر');
  }
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} $hour:$minute';
}
