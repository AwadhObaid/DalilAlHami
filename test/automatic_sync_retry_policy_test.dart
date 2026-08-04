import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/automatic_sync_coordinator.dart';

void main() {
  test('automatic sync retry policy increases delay gradually', () {
    expect(
      AutomaticSyncRetryPolicy.delayForFailure(1),
      const Duration(seconds: 30),
    );
    expect(
      AutomaticSyncRetryPolicy.delayForFailure(2),
      const Duration(minutes: 2),
    );
    expect(
      AutomaticSyncRetryPolicy.delayForFailure(3),
      const Duration(minutes: 5),
    );
    expect(
      AutomaticSyncRetryPolicy.delayForFailure(4),
      const Duration(minutes: 15),
    );
    expect(
      AutomaticSyncRetryPolicy.delayForFailure(12),
      const Duration(minutes: 30),
    );
  });

  test('automatic sync banner visibility follows the current phase', () {
    expect(const AutomaticSyncSnapshot().shouldShowBanner, isFalse);

    expect(
      const AutomaticSyncSnapshot(
        phase: AutomaticSyncPhase.syncing,
      ).shouldShowBanner,
      isTrue,
    );

    expect(
      const AutomaticSyncSnapshot(
        phase: AutomaticSyncPhase.completed,
        announce: false,
      ).shouldShowBanner,
      isFalse,
    );

    expect(
      const AutomaticSyncSnapshot(
        phase: AutomaticSyncPhase.completed,
        announce: true,
      ).shouldShowBanner,
      isTrue,
    );
  });
}
