import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/automatic_sync_coordinator.dart';

void main() {
  test('automatic coordinator prevents overlapping sync runs', () async {
    final completer = Completer<void>();
    var calls = 0;

    final coordinator = AutomaticSyncCoordinator(
      syncAction: () {
        calls++;
        return completer.future;
      },
      networkProbe: () async => true,
      canSync: () => true,
      readMetrics: () => const AutomaticSyncMetrics(
        pendingOperations: 1,
      ),
      automaticSchedulingEnabled: false,
    );

    final first = coordinator.runNow();
    final second = coordinator.runNow();

    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    expect(coordinator.snapshot.isBusy, isTrue);

    completer.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(calls, 1);

    coordinator.dispose();
  });

  test('offline probe changes state without invoking sync action', () async {
    var calls = 0;
    final coordinator = AutomaticSyncCoordinator(
      syncAction: () async {
        calls++;
      },
      networkProbe: () async => false,
      canSync: () => true,
      readMetrics: () => const AutomaticSyncMetrics(
        pendingOperations: 2,
      ),
      automaticSchedulingEnabled: false,
    );

    await coordinator.runNow();

    expect(calls, 0);
    expect(
      coordinator.snapshot.phase,
      AutomaticSyncPhase.offline,
    );
    expect(coordinator.snapshot.nextRetryAt, isNotNull);

    coordinator.dispose();
  });
}
