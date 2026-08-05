import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/background_sync_models.dart';

void main() {
  test('background sync defaults are enabled', () {
    const snapshot = BackgroundSyncSettingsSnapshot();

    expect(snapshot.backgroundSyncEnabled, isTrue);
    expect(snapshot.successNotificationsEnabled, isTrue);
    expect(snapshot.attentionNotificationsEnabled, isTrue);
    expect(snapshot.notificationPermissionGranted, isNull);
    expect(snapshot.lastRunAt, isNull);
  });

  test('copyWith preserves untouched values', () {
    const snapshot = BackgroundSyncSettingsSnapshot(
      backgroundSyncEnabled: true,
      successNotificationsEnabled: true,
      attentionNotificationsEnabled: false,
    );

    final changed = snapshot.copyWith(backgroundSyncEnabled: false);

    expect(changed.backgroundSyncEnabled, isFalse);
    expect(changed.successNotificationsEnabled, isTrue);
    expect(changed.attentionNotificationsEnabled, isFalse);
  });
}
