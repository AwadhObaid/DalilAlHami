import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/background_sync_models.dart';
import '../../core/services/background_sync_service.dart';
import '../../core/services/background_sync_settings.dart';
import '../../core/theme/app_text_styles.dart';

class BackgroundSyncSettingsPage extends StatefulWidget {
  const BackgroundSyncSettingsPage({super.key});

  @override
  State<BackgroundSyncSettingsPage> createState() =>
      _BackgroundSyncSettingsPageState();
}

class _BackgroundSyncSettingsPageState
    extends State<BackgroundSyncSettingsPage> {
  final BackgroundSyncSettingsStore _settings =
      BackgroundSyncSettingsStore.instance;
  final BackgroundSyncService _service = BackgroundSyncService.instance;

  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_handleChanged);
    unawaited(_settings.reload());
  }

  @override
  void dispose() {
    _settings.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _update(Future<void> Function() action) async {
    if (_isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _toggleBackgroundSync(bool value) {
    return _update(() async {
      await _settings.setBackgroundSyncEnabled(value);
      await _service.applySchedule();
    });
  }

  Future<void> _requestPermission() {
    return _update(() async {
      final granted = await _service.requestNotificationPermission();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'تم السماح بإشعارات المزامنة.'
                : 'لم يتم السماح بالإشعارات. يمكنك تفعيلها من إعدادات Android.',
          ),
          backgroundColor: granted ? AppColors.success : AppColors.warning,
        ),
      );
    });
  }

  Future<void> _scheduleTest() {
    return _update(() async {
      await _service.scheduleOneOffSync(
        initialDelay: Duration.zero,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تمت جدولة فحص خلفي. يحدد Android وقت التنفيذ المناسب.',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final snapshot = _settings.snapshot;
    final permission = snapshot.notificationPermissionGranted;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('المزامنة في الخلفية'),
        centerTitle: true,
        backgroundColor: AppColors.primaryTeal,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          _StatusCard(snapshot: snapshot),
          const SizedBox(height: AppSpacing.md),
          _SettingsCard(
            children: <Widget>[
              SwitchListTile.adaptive(
                key: const ValueKey<String>(
                  'background-sync-enabled-switch',
                ),
                value: snapshot.backgroundSyncEnabled,
                onChanged: _isUpdating ? null : _toggleBackgroundSync,
                title: const Text('المزامنة في الخلفية'),
                subtitle: const Text(
                  'تشغيل مهام Android المؤجلة عند توفر الإنترنت والبطارية المناسبة.',
                ),
                secondary: const Icon(Icons.sync_lock_rounded),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                value: snapshot.successNotificationsEnabled,
                onChanged: !snapshot.backgroundSyncEnabled || _isUpdating
                    ? null
                    : (value) => _update(
                          () => _settings.setSuccessNotificationsEnabled(value),
                        ),
                title: const Text('إشعار نجاح المزامنة'),
                subtitle: const Text(
                  'إظهار إشعار بعد إرسال العمليات المعلقة بنجاح.',
                ),
                secondary: const Icon(Icons.task_alt_rounded),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                value: snapshot.attentionNotificationsEnabled,
                onChanged: !snapshot.backgroundSyncEnabled || _isUpdating
                    ? null
                    : (value) => _update(
                          () =>
                              _settings.setAttentionNotificationsEnabled(value),
                        ),
                title: const Text('إشعارات الفشل والتعارض'),
                subtitle: const Text(
                  'تنبيه عند وجود تعارض أو عملية استنفدت محاولاتها.',
                ),
                secondary: const Icon(Icons.notification_important_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsCard(
            children: <Widget>[
              ListTile(
                leading: Icon(
                  permission == true
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  color: permission == true
                      ? AppColors.success
                      : AppColors.warning,
                ),
                title: const Text('إذن إشعارات Android'),
                subtitle: Text(
                  permission == true
                      ? 'مسموح'
                      : permission == false
                          ? 'غير مسموح'
                          : 'لم يُطلب بعد',
                ),
                trailing: FilledButton.tonal(
                  onPressed: _isUpdating ? null : _requestPermission,
                  child: const Text('طلب الإذن'),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: const Text('اختبار الجدولة الآن'),
                subtitle: const Text(
                  'يسجل مهمة فورية، وقد يؤخر Android تنفيذها وفق حالة الجهاز.',
                ),
                trailing: IconButton(
                  tooltip: AppLocaleText.runtime('جدولة اختبار'),
                  onPressed: !snapshot.backgroundSyncEnabled || _isUpdating
                      ? null
                      : _scheduleTest,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.primaryTeal.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              'تعمل المزامنة الدورية بحد أدنى 15 دقيقة، لكن Android قد يؤخرها '
              'للحفاظ على البطارية. إغلاق التطبيق لا يلغي المهمة المجدولة، '
              'بينما الإيقاف الإجباري من إعدادات النظام يوقفها حتى فتح التطبيق مجددًا.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.snapshot});

  final BackgroundSyncSettingsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final enabled = snapshot.backgroundSyncEnabled;
    final status = snapshot.lastRunStatus;
    final color = enabled ? AppColors.primaryTeal : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            enabled ? Icons.cloud_sync_rounded : Icons.cloud_off_rounded,
            color: color,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  enabled ? 'الجدولة الخلفية مفعلة' : 'الجدولة الخلفية متوقفة',
                  style: AppTextStyles.titleMedium.copyWith(color: color),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  snapshot.lastRunLabel,
                  style: AppTextStyles.bodySmall,
                ),
                if (status != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    snapshot.lastRunMessage ?? status,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(children: children),
    );
  }
}
