import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/automatic_sync_coordinator.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';

class HomeSyncStrip extends StatelessWidget {
  const HomeSyncStrip({
    this.coordinator,
    super.key,
  });

  final AutomaticSyncCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final resolved = coordinator ?? AutomaticSyncCoordinator.instance;

    return AnimatedBuilder(
      animation: resolved,
      builder: (context, child) {
        final snapshot = resolved.snapshot;
        final visual = _SyncVisual.fromPhase(snapshot.phase);

        return Container(
          key: const ValueKey<String>('home-sync-strip'),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: visual.background,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: visual.foreground.withValues(alpha: 0.22),
            ),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: snapshot.isBusy
                    ? Padding(
                        padding: const EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: visual.foreground,
                        ),
                      )
                    : Icon(
                        visual.icon,
                        color: visual.foreground,
                        size: 25,
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visual.title,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: visual.foreground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _messageFor(snapshot),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              FilledButton.icon(
                key: const ValueKey<String>('home-sync-now-button'),
                onPressed: snapshot.isBusy
                    ? null
                    : () {
                        resolved.runNow(
                          trigger: AutomaticSyncTrigger.manual,
                        );
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: AppColors.white,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('مزامنة'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _messageFor(AutomaticSyncSnapshot snapshot) {
    final lastCompletedAt = snapshot.lastCompletedAt?.toLocal();
    if (snapshot.phase == AutomaticSyncPhase.idle && lastCompletedAt != null) {
      final minute = lastCompletedAt.minute.toString().padLeft(2, '0');
      return 'آخر مزامنة ${lastCompletedAt.hour}:$minute';
    }

    final retry = snapshot.nextRetryLabel;
    if (retry != null) {
      return '${snapshot.message} المحاولة التالية: $retry';
    }

    return snapshot.message;
  }
}

class _SyncVisual {
  const _SyncVisual({
    required this.title,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String title;
  final IconData icon;
  final Color foreground;
  final Color background;

  static _SyncVisual fromPhase(AutomaticSyncPhase phase) {
    return switch (phase) {
      AutomaticSyncPhase.checkingConnection ||
      AutomaticSyncPhase.syncing =>
        _SyncVisual(
          title: 'جاري المزامنة',
          icon: Icons.sync_rounded,
          foreground: AppColors.primaryTeal,
          background: AppColors.primarySoft,
        ),
      AutomaticSyncPhase.completed => _SyncVisual(
          title: 'تمت المزامنة',
          icon: Icons.cloud_done_rounded,
          foreground: AppColors.success,
          background: AppColors.mintSoft,
        ),
      AutomaticSyncPhase.offline ||
      AutomaticSyncPhase.waitingRetry =>
        _SyncVisual(
          title: 'غير متصل حاليًا',
          icon: Icons.cloud_off_rounded,
          foreground: AppColors.warning,
          background: AppColors.warningSoft,
        ),
      AutomaticSyncPhase.attentionRequired => _SyncVisual(
          title: 'تحتاج المزامنة إلى مراجعة',
          icon: Icons.sync_problem_rounded,
          foreground: AppColors.danger,
          background: AppColors.dangerSoft,
        ),
      AutomaticSyncPhase.idle => _SyncVisual(
          title: 'المزامنة التلقائية مفعلة',
          icon: Icons.cloud_done_rounded,
          foreground: AppColors.success,
          background: AppColors.mintSoft,
        ),
    };
  }
}
