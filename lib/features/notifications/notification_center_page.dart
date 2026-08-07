import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/app_notification_store.dart';
import '../../core/services/push_notification_intent.dart';
import '../../core/services/push_notification_navigation_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/notification_repository.dart';
import '../../models/app_notification.dart';

typedef NotificationCenterLoader = Future<List<AppNotification>> Function();
typedef NotificationReadExecutor = Future<bool> Function(String notificationId);
typedef NotificationsReadAllExecutor = Future<int> Function();

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({
    super.key,
    this.loader,
    this.readExecutor,
    this.readAllExecutor,
  });

  final NotificationCenterLoader? loader;
  final NotificationReadExecutor? readExecutor;
  final NotificationsReadAllExecutor? readAllExecutor;

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  final NotificationRepository _repository = const NotificationRepository();
  final AppNotificationStore _store = AppNotificationStore.instance;

  List<AppNotification> _items = const <AppNotification>[];
  bool _loading = true;
  bool _markingAll = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final loader = widget.loader ?? _repository.loadMyNotifications;
      final items = await loader();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
      await _store.refreshUnreadCount();
    } on NotificationRepositoryFailure catch (error) {
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
            'تعذر تحميل الإشعارات. تحقق من الاتصال ثم أعد المحاولة.';
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll || !_items.any((item) => !item.isRead)) {
      return;
    }

    setState(() => _markingAll = true);
    try {
      final executor = widget.readAllExecutor ?? _store.markAllRead;
      await executor();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = _items
            .map((item) => item.isRead ? item : item.copyWith(isRead: true))
            .toList(growable: false);
      });
    } on NotificationRepositoryFailure catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر تحديث حالة الإشعارات. أعد المحاولة.');
      }
    } finally {
      if (mounted) {
        setState(() => _markingAll = false);
      }
    }
  }

  Future<void> _openItem(AppNotification item) async {
    if (!item.isRead) {
      try {
        final executor = widget.readExecutor ?? _store.markRead;
        final changed = await executor(item.id);
        if (changed && mounted) {
          setState(() {
            _items = _items
                .map(
                  (value) => value.id == item.id
                      ? value.copyWith(isRead: true)
                      : value,
                )
                .toList(growable: false);
          });
        }
      } on NotificationRepositoryFailure catch (error) {
        if (mounted) {
          _showMessage(error.message);
        }
        return;
      } catch (_) {
        if (mounted) {
          _showMessage('تعذر تحديث حالة الإشعار. أعد المحاولة.');
        }
        return;
      }
    }

    final intent = item.intent;
    if (intent == null ||
        intent.target == PushNotificationTarget.notifications) {
      return;
    }
    await PushNotificationNavigationService.instance.openOrQueue(intent);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final unreadCount = _items.where((item) => !item.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('مركز الإشعارات'),
        actions: [
          TextButton.icon(
            key: const ValueKey<String>('notification-mark-all-read'),
            onPressed: _markingAll || unreadCount == 0 ? null : _markAllRead,
            icon: _markingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded),
            label: const Text('قراءة الكل'),
          ),
        ],
      ),
      body: _buildBody(unreadCount),
    );
  }

  Widget _buildBody(int unreadCount) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _items.isEmpty) {
      return _NotificationStateView(
        icon: Icons.notifications_off_outlined,
        title: 'تعذر فتح مركز الإشعارات',
        message: _errorMessage!,
        actionLabel: 'إعادة المحاولة',
        onAction: _load,
      );
    }

    if (_items.isEmpty) {
      return const _NotificationStateView(
        icon: Icons.notifications_none_rounded,
        title: 'لا توجد إشعارات حتى الآن',
        message: 'ستظهر هنا تنبيهات دليل الحامي والرسائل الموجهة إلى حسابك.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        key: const PageStorageKey<String>('notification-center-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        itemCount: _items.length + 1,
        separatorBuilder: (_, index) => index == 0
            ? const SizedBox(height: AppSpacing.md)
            : const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _NotificationSummaryCard(
              totalCount: _items.length,
              unreadCount: unreadCount,
            );
          }
          final item = _items[index - 1];
          return _NotificationCard(
            item: item,
            onTap: () => _openItem(item),
          );
        },
      ),
    );
  }
}

class _NotificationSummaryCard extends StatelessWidget {
  const _NotificationSummaryCard({
    required this.totalCount,
    required this.unreadCount,
  });

  final int totalCount;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.primaryTeal,
            foregroundColor: AppColors.white,
            child: Icon(Icons.notifications_active_rounded),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إشعارات دليل الحامي', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  unreadCount == 0
                      ? 'كل الإشعارات مقروءة'
                      : '$unreadCount غير مقروء من أصل $totalCount',
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Material(
      color: item.isRead ? AppColors.surface : AppColors.surfaceTint,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        key: ValueKey<String>('notification-item-${item.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: item.isRead ? AppColors.outline : AppColors.lightTeal,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.isRead
                      ? AppColors.surfaceMuted
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  item.isRead
                      ? Icons.notifications_none_rounded
                      : Icons.notifications_active_rounded,
                  color: item.isRead
                      ? AppColors.textSecondary
                      : AppColors.primaryTeal,
                ),
              ),
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
                            item.title,
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: AppColors.advertisementGold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(item.body, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          _formatDate(item.createdAt),
                          style: AppTextStyles.bodySmall,
                        ),
                        const Spacer(),
                        if (item.intent != null &&
                            item.intent!.target !=
                                PushNotificationTarget.notifications)
                          const Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) {
      return 'الآن';
    }
    if (difference.inHours < 1) {
      return 'قبل ${difference.inMinutes} دقيقة';
    }
    if (difference.inDays < 1) {
      return 'قبل ${difference.inHours} ساعة';
    }
    if (difference.inDays < 7) {
      return 'قبل ${difference.inDays} يوم';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _NotificationStateView extends StatelessWidget {
  const _NotificationStateView({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: AppColors.primaryTeal),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
