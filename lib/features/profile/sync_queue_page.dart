import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../../data/sync_queue/sync_queue_item.dart';

class SyncQueuePage extends StatefulWidget {
  const SyncQueuePage({super.key});

  @override
  State<SyncQueuePage> createState() => _SyncQueuePageState();
}

class _SyncQueuePageState extends State<SyncQueuePage> {
  final DirectoryDataStore _store = DirectoryDataStore.instance;

  List<SyncQueueItem> _items = const [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _store.addListener(_handleStoreChanged);
    _load();
  }

  @override
  void dispose() {
    _store.removeListener(_handleStoreChanged);
    super.dispose();
  }

  void _handleStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _store.readCurrentUserSyncOperations();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
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
          _isLoading = false;
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
      await _store.processSyncQueueNow();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('عمليات المزامنة'),
        centerTitle: true,
        backgroundColor: AppColors.primaryTeal,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
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

  Widget _buildSummary() {
    final summary = _store.syncQueueSummary;
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
        children: [
          _SummaryValue(label: 'معلقة', value: summary.actionable),
          _SummaryValue(label: 'مكتملة', value: summary.completed),
          _SummaryValue(label: 'فاشلة', value: summary.failed),
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
          return _QueueOperationCard(
            item: _items[index],
            onRetry: _retry,
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
  });

  final SyncQueueItem item;
  final Future<void> Function(SyncQueueItem item) onRetry;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.status) {
      SyncQueueStatus.completed => AppColors.success,
      SyncQueueStatus.failed => AppColors.danger,
      SyncQueueStatus.processing => AppColors.primaryTeal,
      SyncQueueStatus.pending => AppColors.warning,
    };
    final localTime = item.updatedAt.toLocal();
    final timeLabel = '${localTime.day.toString().padLeft(2, '0')}/'
        '${localTime.month.toString().padLeft(2, '0')} '
        '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_rounded, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.operationType.label,
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
                  item.status.label,
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
          if (item.lastError != null) ...[
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
          if (item.status == SyncQueueStatus.failed) ...[
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
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value.toString(), style: AppTextStyles.titleLarge),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
