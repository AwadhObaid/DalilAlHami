import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/automatic_sync_coordinator.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../../data/sync_queue/sync_conflict.dart';
import '../../data/sync_queue/sync_queue_item.dart';

class SyncQueuePage extends StatefulWidget {
  const SyncQueuePage({super.key});

  @override
  State<SyncQueuePage> createState() => _SyncQueuePageState();
}

class _SyncQueuePageState extends State<SyncQueuePage> {
  final DirectoryDataStore _store = DirectoryDataStore.instance;
  final AutomaticSyncCoordinator _syncCoordinator =
      AutomaticSyncCoordinator.instance;

  List<SyncQueueItem> _items = const <SyncQueueItem>[];
  Map<String, SyncConflict> _conflictsByOperation =
      const <String, SyncConflict>{};
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _resolvingConflictId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _store.addListener(_handleStoreChanged);
    _syncCoordinator.addListener(_handleAutomaticSyncChanged);
    _load();
  }

  @override
  void dispose() {
    _store.removeListener(_handleStoreChanged);
    _syncCoordinator.removeListener(_handleAutomaticSyncChanged);
    super.dispose();
  }

  void _handleStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleAutomaticSyncChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
    final phase = _syncCoordinator.snapshot.phase;
    if (phase == AutomaticSyncPhase.completed ||
        phase == AutomaticSyncPhase.attentionRequired) {
      unawaited(_load(showLoading: false));
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final items = await _store.readCurrentUserSyncOperations();
      final conflicts = await _store.readCurrentUserSyncConflicts();

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _conflictsByOperation = <String, SyncConflict>{
          for (final conflict in conflicts) conflict.operationId: conflict,
        };
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (showLoading) {
            _isLoading = false;
          }
        });
      }
    }
  }

  Future<void> _processNow() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await _syncCoordinator.runNow(
        trigger: AutomaticSyncTrigger.manual,
      );
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _retry(SyncQueueItem item) async {
    await _store.retryFailedSyncOperations(operationId: item.id);
    await _load();
  }

  Future<void> _openConflict(
    SyncQueueItem item,
    SyncConflict conflict,
  ) async {
    final resolution = await showModalBottomSheet<_ConflictResolution>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ConflictResolutionSheet(
          item: item,
          conflict: conflict,
        );
      },
    );

    if (resolution == null || !mounted) {
      return;
    }

    setState(() {
      _resolvingConflictId = conflict.id;
    });

    try {
      switch (resolution) {
        case _ConflictResolution.keepLocal:
          await _store.resolveSyncConflictKeepLocal(conflict);
          break;
        case _ConflictResolution.useServer:
          await _store.resolveSyncConflictUseServer(conflict);
          break;
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resolution == _ConflictResolution.keepLocal
                  ? 'تم إنشاء عملية جديدة للاحتفاظ بتعديلاتك.'
                  : 'تم اعتماد نسخة الخادم المحفوظة.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _resolvingConflictId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('عمليات المزامنة'),
        centerTitle: true,
        backgroundColor: AppColors.primaryTeal,
        actions: <Widget>[
          IconButton(
            tooltip: AppLocaleText.runtime('تحديث'),
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildAutomaticSyncCard(),
          _buildSummary(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.md),
        child: ElevatedButton.icon(
          onPressed: _isProcessing ? null : _processNow,
          icon: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync_rounded),
          label: Text(
            _isProcessing ? 'جارٍ تنفيذ العمليات' : 'مزامنة الآن',
          ),
        ),
      ),
    );
  }

  Widget _buildAutomaticSyncCard() {
    final snapshot = _syncCoordinator.snapshot;
    final retryLabel = snapshot.nextRetryLabel;
    final color = switch (snapshot.phase) {
      AutomaticSyncPhase.attentionRequired => AppColors.danger,
      AutomaticSyncPhase.offline ||
      AutomaticSyncPhase.waitingRetry =>
        AppColors.warning,
      AutomaticSyncPhase.completed => AppColors.success,
      _ => AppColors.primaryTeal,
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          if (snapshot.isBusy)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(Icons.sync_rounded, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'المزامنة التلقائية',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: color,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  retryLabel == null
                      ? snapshot.message
                      : '${snapshot.message} الموعد التالي: $retryLabel',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final summary = _store.syncQueueSummary;
    final conflictCount = _conflictsByOperation.values
        .where((conflict) => conflict.isPending)
        .length;
    final ordinaryFailureCount =
        summary.failed > conflictCount ? summary.failed - conflictCount : 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.spaceAround,
        children: <Widget>[
          _SummaryValue(label: 'معلقة', value: summary.actionable),
          _SummaryValue(label: 'تعارضات', value: conflictCount),
          _SummaryValue(label: 'مكتملة', value: summary.completed),
          _SummaryValue(
            label: 'فاشلة',
            value: ordinaryFailureCount,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.danger,
            ),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text('لا توجد عمليات مزامنة محفوظة.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = _items[index];
          final conflict = _conflictsByOperation[item.id];
          return _QueueOperationCard(
            item: item,
            conflict: conflict,
            isResolving:
                conflict != null && _resolvingConflictId == conflict.id,
            onRetry: _retry,
            onResolveConflict: _openConflict,
          );
        },
      ),
    );
  }
}

class _QueueOperationCard extends StatelessWidget {
  const _QueueOperationCard({
    required this.item,
    required this.onRetry,
    required this.onResolveConflict,
    required this.isResolving,
    this.conflict,
  });

  final SyncQueueItem item;
  final SyncConflict? conflict;
  final bool isResolving;
  final Future<void> Function(SyncQueueItem item) onRetry;
  final Future<void> Function(
    SyncQueueItem item,
    SyncConflict conflict,
  ) onResolveConflict;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final pendingConflict = conflict?.isPending == true;
    final color = pendingConflict
        ? AppColors.warning
        : switch (item.status) {
            SyncQueueStatus.completed => AppColors.success,
            SyncQueueStatus.failed => AppColors.danger,
            SyncQueueStatus.processing => AppColors.primaryTeal,
            SyncQueueStatus.pending => AppColors.warning,
          };
    final statusLabel =
        pendingConflict ? 'تعارض يحتاج قرارًا' : item.status.label;
    final localTime = item.updatedAt.toLocal();
    final timeLabel = '${localTime.day.toString().padLeft(2, '0')}/'
        '${localTime.month.toString().padLeft(2, '0')} '
        '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}';

    return Container(
      key: ValueKey<String>('sync-operation-${item.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                pendingConflict
                    ? Icons.warning_amber_rounded
                    : Icons.storefront_rounded,
                color: color,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  pendingConflict
                      ? '${item.operationType.label}: '
                          '${conflict!.entityName}'
                      : item.operationType.label,
                  style: AppTextStyles.titleSmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  statusLabel,
                  style: AppTextStyles.bodySmall.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'آخر تحديث: $timeLabel • المحاولات: '
            '${item.attemptCount}/${item.maxAttempts}',
            style: AppTextStyles.bodySmall,
          ),
          if (pendingConflict) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'تم تعديل النشاط في الخادم بعد النسخة التي بدأت منها. '
              'لن تُفقد أي نسخة حتى تختار طريقة الحل.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: ValueKey<String>(
                  'resolve-conflict-${item.id}',
                ),
                onPressed: isResolving
                    ? null
                    : () => onResolveConflict(item, conflict!),
                icon: isResolving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.rule_folder_rounded),
                label: const Text('مراجعة وحل التعارض'),
              ),
            ),
          ] else ...<Widget>[
            if (item.lastError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.lastError!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],
            if (item.status == SyncQueueStatus.failed) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onRetry(item),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

enum _ConflictResolution {
  keepLocal,
  useServer,
}

class _ConflictResolutionSheet extends StatelessWidget {
  const _ConflictResolutionSheet({
    required this.item,
    required this.conflict,
  });

  final SyncQueueItem item;
  final SyncConflict conflict;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final local = conflict.localPayload;
    final server = conflict.serverSnapshot;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 48),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.pageBackground,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'حل تعارض ${item.operationType.label}',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'نسختك بدأت من الإصدار '
                '${conflict.expectedSyncVersion}، بينما الخادم أصبح '
                'في الإصدار ${conflict.serverSyncVersion}.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _ConflictVersionCard(
                      title: 'تعديلاتك المحلية',
                      icon: Icons.phone_android_rounded,
                      values: local,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ConflictVersionCard(
                      title: 'نسخة الخادم',
                      icon: Icons.cloud_rounded,
                      values: server,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                key: const ValueKey<String>(
                  'keep-local-conflict-button',
                ),
                onPressed: () {
                  Navigator.of(context).pop(
                    _ConflictResolution.keepLocal,
                  );
                },
                icon: const Icon(Icons.upload_rounded),
                label: const Text('الاحتفاظ بتعديلاتي وإرسالها مجددًا'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const ValueKey<String>(
                  'use-server-conflict-button',
                ),
                onPressed: () {
                  Navigator.of(context).pop(
                    _ConflictResolution.useServer,
                  );
                },
                icon: const Icon(Icons.cloud_download_rounded),
                label: const Text('اعتماد نسخة الخادم'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('القرار لاحقًا'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConflictVersionCard extends StatelessWidget {
  const _ConflictVersionCard({
    required this.title,
    required this.icon,
    required this.values,
  });

  final String title;
  final IconData icon;
  final Map<String, dynamic> values;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: AppColors.primaryTeal),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleSmall,
                ),
              ),
            ],
          ),
          const Divider(),
          _ConflictField(
            label: 'الاسم',
            value: values['name']?.toString(),
          ),
          _ConflictField(
            label: 'الهاتف',
            value: values['phone']?.toString(),
          ),
          _ConflictField(
            label: 'العنوان',
            value: values['address']?.toString(),
          ),
          _ConflictField(
            label: 'الوصف',
            value: values['description']?.toString(),
          ),
        ],
      ),
    );
  }
}

class _ConflictField extends StatelessWidget {
  const _ConflictField({
    required this.label,
    required this.value,
  });

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final displayValue =
        value == null || value!.trim().isEmpty ? '—' : value!.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppTextStyles.labelSmall),
          Text(
            displayValue,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(value.toString(), style: AppTextStyles.titleLarge),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
