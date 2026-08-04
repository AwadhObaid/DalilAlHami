import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/automatic_sync_coordinator.dart';
import 'package:hami_guide/features/home/widgets/automatic_sync_status_banner.dart';

void main() {
  testWidgets('automatic sync banner appears while offline', (tester) async {
    final coordinator = AutomaticSyncCoordinator(
      syncAction: () async {},
      networkProbe: () async => false,
      canSync: () => true,
      readMetrics: () => const AutomaticSyncMetrics(
        pendingOperations: 1,
      ),
      automaticSchedulingEnabled: false,
    );

    await coordinator.runNow();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AutomaticSyncStatusBanner(
            coordinator: coordinator,
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey<String>('automatic-sync-status-banner'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('لا يوجد اتصال'), findsOneWidget);
    expect(find.text('حاول الآن'), findsOneWidget);

    coordinator.dispose();
  });
}
