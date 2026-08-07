import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/admin_content_repository.dart';
import '../../data/repositories/admin_notification_repository.dart';
import '../../models/account_profile.dart';
import '../../models/admin_advertisement_management.dart';
import '../../models/admin_notification_management.dart';
import '../../data/repositories/admin_repository.dart';

typedef AdminNotificationProfileLoader = Future<AccountProfile> Function();
typedef AdminNotificationUsersLoader = Future<List<AdminNotificationUserOption>>
    Function();
typedef AdminNotificationHistoryLoader
    = Future<List<AdminNotificationHistoryItem>> Function();
typedef AdminNotificationBusinessesLoader
    = Future<List<AdminAdvertisementBusinessOption>> Function();
typedef AdminNotificationSender = Future<AdminNotificationSendResult> Function({
  required String title,
  required String body,
  required AdminNotificationAudience audience,
  required AdminNotificationNavigation navigation,
  String? targetUserId,
  String? businessId,
});

class AdminNotificationManagementPage extends StatefulWidget {
  const AdminNotificationManagementPage({
    super.key,
    this.profileLoader,
    this.usersLoader,
    this.historyLoader,
    this.businessesLoader,
    this.sender,
  });

  final AdminNotificationProfileLoader? profileLoader;
  final AdminNotificationUsersLoader? usersLoader;
  final AdminNotificationHistoryLoader? historyLoader;
  final AdminNotificationBusinessesLoader? businessesLoader;
  final AdminNotificationSender? sender;

  @override
  State<AdminNotificationManagementPage> createState() =>
      _AdminNotificationManagementPageState();
}

class _AdminNotificationManagementPageState
    extends State<AdminNotificationManagementPage> {
  final AdminNotificationRepository _repository = AdminNotificationRepository();
  final AdminContentRepository _contentRepository = AdminContentRepository();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  String? _errorMessage;
  AdminNotificationAudience _audience = AdminNotificationAudience.public;
  AdminNotificationNavigation _navigation =
      AdminNotificationNavigation.notifications;
  String? _targetUserId;
  String? _businessId;
  List<AdminNotificationUserOption> _users =
      const <AdminNotificationUserOption>[];
  List<AdminAdvertisementBusinessOption> _businesses =
      const <AdminAdvertisementBusinessOption>[];
  List<AdminNotificationHistoryItem> _history =
      const <AdminNotificationHistoryItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final profile = await (widget.profileLoader?.call() ??
          _repository.loadCurrentAdminProfile());
      if (!profile.isAdmin || !profile.isActive) {
        throw const AdminAccessDenied(
          'هذا الحساب لا يملك صلاحية إدارة الإشعارات.',
        );
      }

      final results = await Future.wait<Object>([
        widget.usersLoader?.call() ?? _repository.loadUserOptions(),
        widget.historyLoader?.call() ?? _repository.loadHistory(),
        widget.businessesLoader?.call() ??
            _contentRepository.loadAdvertisementBusinesses(),
      ]);

      if (!mounted) {
        return;
      }
      setState(() {
        _users = results[0] as List<AdminNotificationUserOption>;
        _history = results[1] as List<AdminNotificationHistoryItem>;
        _businesses = results[2] as List<AdminAdvertisementBusinessOption>;
        _targetUserId = _users.any((user) => user.id == _targetUserId)
            ? _targetUserId
            : null;
        _businessId = _businesses.any((item) => item.id == _businessId)
            ? _businessId
            : null;
        _loading = false;
      });
    } on AdminAccessDenied catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _loading = false;
      });
    } on AdminNotificationRepositoryFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage =
            'تعذر تحميل إدارة الإشعارات. تحقق من الاتصال ثم أعد المحاولة.';
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    if (_sending || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_audience == AdminNotificationAudience.user && _targetUserId == null) {
      _showMessage('اختر المستخدم المستهدف.');
      return;
    }
    if (_navigation == AdminNotificationNavigation.business &&
        _businessId == null) {
      _showMessage('اختر النشاط الذي سيفتحه الإشعار.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد إرسال الإشعار'),
        content: Text(
          _audience == AdminNotificationAudience.public
              ? 'سيتم إرسال هذا الإشعار إلى جميع الأجهزة المشتركة في دليل الحامي.'
              : 'سيتم إرسال هذا الإشعار إلى المستخدم المحدد وأجهزته النشطة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            key: const ValueKey<String>('admin-notification-send-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.send_rounded),
            label: const Text('إرسال'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _sending = true);
    try {
      final sender = widget.sender ?? _repository.send;
      final result = await sender(
        title: _titleController.text,
        body: _bodyController.text,
        audience: _audience,
        navigation: _navigation,
        targetUserId: _targetUserId,
        businessId: _businessId,
      );
      if (!mounted) {
        return;
      }
      _showMessage(result.message);
      _titleController.clear();
      _bodyController.clear();
      setState(() {
        _audience = AdminNotificationAudience.public;
        _navigation = AdminNotificationNavigation.notifications;
        _targetUserId = null;
        _businessId = null;
      });
      await _load();
    } on AdminAccessDenied catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } on AdminNotificationRepositoryFailure catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر إرسال الإشعار. تحقق من الاتصال ثم أعد المحاولة.');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('إدارة الإشعارات'),
        actions: [
          IconButton(
            tooltip: AppLocaleText.runtime('تحديث'),
            onPressed: _loading || _sending ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _history.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _history.isEmpty) {
      return _AdminNotificationStateView(
        message: _errorMessage!,
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const PageStorageKey<String>('admin-notification-management-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          _buildIntroCard(),
          const SizedBox(height: AppSpacing.lg),
          Text('إنشاء إشعار', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          _buildComposer(),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text('آخر الإشعارات المرسلة',
                    style: AppTextStyles.titleLarge),
              ),
              Text('${_history.length} سجل', style: AppTextStyles.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_history.isEmpty)
            const _AdminNotificationEmptyHistory()
          else
            ..._history.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _AdminNotificationHistoryCard(item: item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryTeal,
            foregroundColor: AppColors.white,
            child: Icon(Icons.campaign_rounded),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'الإرسال يتم من الخادم عبر Firebase Cloud Messaging. مفاتيح Firebase السرية لا تُحفظ داخل التطبيق.',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              key: const ValueKey<String>('admin-notification-title-field'),
              controller: _titleController,
              enabled: !_sending,
              maxLength: 120,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: AppLocaleText.runtime('عنوان الإشعار'),
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.length < 2) {
                  return AppLocaleText.runtime('اكتب عنوانًا واضحًا.');
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('admin-notification-body-field'),
              controller: _bodyController,
              enabled: !_sending,
              minLines: 3,
              maxLines: 5,
              maxLength: 600,
              decoration: InputDecoration(
                labelText: AppLocaleText.runtime('نص الإشعار'),
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.message_rounded),
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? AppLocaleText.runtime('اكتب نص الإشعار.')
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<AdminNotificationAudience>(
              key: const ValueKey<String>('admin-notification-audience-field'),
              initialValue: _audience,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppLocaleText.runtime('المستلمون'),
                prefixIcon: Icon(Icons.groups_rounded),
              ),
              items: AdminNotificationAudience.values
                  .map(
                    (value) => DropdownMenuItem<AdminNotificationAudience>(
                      value: value,
                      child: Text(value.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _sending
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _audience = value;
                          if (value == AdminNotificationAudience.public) {
                            _targetUserId = null;
                          }
                        });
                      }
                    },
            ),
            if (_audience == AdminNotificationAudience.user) ...[
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: const ValueKey<String>(
                  'admin-notification-target-user-field',
                ),
                initialValue: _users.any((item) => item.id == _targetUserId)
                    ? _targetUserId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppLocaleText.runtime('المستخدم المستهدف'),
                  prefixIcon: Icon(Icons.person_search_rounded),
                ),
                items: _users
                    .map(
                      (user) => DropdownMenuItem<String>(
                        value: user.id,
                        child: Text(
                          '${user.name} — ${user.secondaryLabel}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _sending
                    ? null
                    : (value) => setState(() => _targetUserId = value),
                validator: (_) => _targetUserId == null
                    ? AppLocaleText.runtime('اختر المستخدم المستهدف.')
                    : null,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<AdminNotificationNavigation>(
              key: const ValueKey<String>(
                'admin-notification-navigation-field',
              ),
              initialValue: _navigation,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppLocaleText.runtime('عند الضغط على الإشعار'),
                prefixIcon: Icon(Icons.ads_click_rounded),
              ),
              items: AdminNotificationNavigation.values
                  .map(
                    (value) => DropdownMenuItem<AdminNotificationNavigation>(
                      value: value,
                      child: Text(value.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _sending
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _navigation = value;
                          if (value != AdminNotificationNavigation.business) {
                            _businessId = null;
                          }
                        });
                      }
                    },
            ),
            if (_navigation == AdminNotificationNavigation.business) ...[
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: const ValueKey<String>(
                  'admin-notification-business-field',
                ),
                initialValue: _businesses.any((item) => item.id == _businessId)
                    ? _businessId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppLocaleText.runtime('النشاط المرتبط'),
                  prefixIcon: Icon(Icons.storefront_rounded),
                ),
                items: _businesses
                    .map(
                      (business) => DropdownMenuItem<String>(
                        value: business.id,
                        child: Text(
                          business.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _sending
                    ? null
                    : (value) => setState(() => _businessId = value),
                validator: (_) => _businessId == null
                    ? AppLocaleText.runtime('اختر النشاط المرتبط.')
                    : null,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey<String>('admin-notification-send-button'),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'جارٍ الإرسال…' : 'إرسال الإشعار'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNotificationHistoryCard extends StatelessWidget {
  const _AdminNotificationHistoryCard({required this.item});

  final AdminNotificationHistoryItem item;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final statusColor = switch (item.deliveryStatus) {
      'sent' => AppColors.success,
      'partial' || 'no_devices' => AppColors.warning,
      'failed' => AppColors.danger,
      _ => AppColors.textSecondary,
    };
    final statusLabel = switch (item.deliveryStatus) {
      'sent' => 'تم الإرسال',
      'partial' => 'إرسال جزئي',
      'no_devices' => 'محفوظ بدون جهاز',
      'failed' => 'فشل الإرسال',
      _ => 'قيد الإرسال',
    };
    final targetLabel = item.targetType == 'public'
        ? 'جميع المستخدمين'
        : item.targetUserName ?? 'مستخدم محدد';

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
              Expanded(
                child: Text(item.title, style: AppTextStyles.titleSmall),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  statusLabel,
                  style: AppTextStyles.labelSmall.copyWith(color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _HistoryMeta(icon: Icons.people_rounded, label: targetLabel),
              _HistoryMeta(
                icon: Icons.send_to_mobile_rounded,
                label: '${item.successCount}/${item.attemptCount}',
              ),
              _HistoryMeta(
                icon: Icons.schedule_rounded,
                label: _dateLabel(item.createdAt),
              ),
            ],
          ),
          if (item.businessName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _HistoryMeta(
              icon: Icons.storefront_rounded,
              label: item.businessName!,
            ),
          ],
          if (item.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.errorMessage!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }

  String _dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month ${value.year} — $hour:$minute';
  }
}

class _HistoryMeta extends StatelessWidget {
  const _HistoryMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xxs),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _AdminNotificationEmptyHistory extends StatelessWidget {
  const _AdminNotificationEmptyHistory();

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 42,
            color: AppColors.textMuted,
          ),
          SizedBox(height: AppSpacing.sm),
          Text('لم يتم إرسال إشعارات من لوحة الإدارة بعد.'),
        ],
      ),
    );
  }
}

class _AdminNotificationStateView extends StatelessWidget {
  const _AdminNotificationStateView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 54,
              color: AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
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
