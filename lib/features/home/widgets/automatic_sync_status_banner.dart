import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/automatic_sync_coordinator.dart';
import '../../../core/theme/app_text_styles.dart';

class AutomaticSyncStatusBanner extends StatelessWidget {
  const AutomaticSyncStatusBanner({
    this.coordinator,
    super.key,
  });

  final AutomaticSyncCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final resolvedCoordinator =
        coordinator ?? AutomaticSyncCoordinator.instance;

    return AnimatedBuilder(
      animation: resolvedCoordinator,
      builder: (context, child) {
        final snapshot = resolvedCoordinator.snapshot;
        if (!snapshot.shouldShowBanner) {
          return const SizedBox.shrink();
        }

        final visual = _visualFor(snapshot.phase);
        final retryLabel = snapshot.nextRetryLabel;

        return SafeArea(
          bottom: false,
          child: Container(
            key: const ValueKey<String>(
              'automatic-sync-status-banner',
            ),
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
              0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: visual.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: visual.foreground.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: <Widget>[
                if (snapshot.isBusy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: visual.foreground,
                    ),
                  )
                else
                  Icon(
                    visual.icon,
                    size: 20,
                    color: visual.foreground,
                  ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    retryLabel == null
                        ? snapshot.message
                        : '${snapshot.message} المحاولة التالية: $retryLabel',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: visual.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!snapshot.isBusy &&
                    snapshot.phase != AutomaticSyncPhase.completed)
                  TextButton(
                    key: const ValueKey<String>(
                      'automatic-sync-retry-button',
                    ),
                    onPressed: () {
                      resolvedCoordinator.runNow(
                        trigger: AutomaticSyncTrigger.manual,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: visual.foreground,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('حاول الآن'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  _AutomaticSyncVisual _visualFor(AutomaticSyncPhase phase) {
    return switch (phase) {
      AutomaticSyncPhase.checkingConnection ||
      AutomaticSyncPhase.syncing =>
        _AutomaticSyncVisual(
          icon: Icons.sync_rounded,
          foreground: AppColors.primaryTeal,
          background: AppColors.primarySoft,
        ),
      AutomaticSyncPhase.completed => _AutomaticSyncVisual(
          icon: Icons.cloud_done_rounded,
          foreground: AppColors.success,
          background: AppColors.mintSoft,
        ),
      AutomaticSyncPhase.offline ||
      AutomaticSyncPhase.waitingRetry =>
        _AutomaticSyncVisual(
          icon: Icons.cloud_off_rounded,
          foreground: AppColors.warning,
          background: AppColors.warningSoft,
        ),
      AutomaticSyncPhase.attentionRequired => _AutomaticSyncVisual(
          icon: Icons.sync_problem_rounded,
          foreground: AppColors.danger,
          background: AppColors.dangerSoft,
        ),
      AutomaticSyncPhase.idle => _AutomaticSyncVisual(
          icon: Icons.cloud_done_rounded,
          foreground: AppColors.textSecondary,
          background: AppColors.surfaceMuted,
        ),
    };
  }
}

class _AutomaticSyncVisual {
  const _AutomaticSyncVisual({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
}
