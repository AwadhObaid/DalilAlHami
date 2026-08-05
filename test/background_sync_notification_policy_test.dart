import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/background_sync_models.dart';

void main() {
  test('success notification is emitted only after completed work', () {
    final decision = BackgroundSyncNotificationDecision.evaluate(
      successNotificationsEnabled: true,
      attentionNotificationsEnabled: true,
      completedOperations: 2,
      exhaustedOperations: 0,
      pendingConflicts: 0,
    );

    expect(decision.showSuccess, isTrue);
    expect(decision.showAttention, isFalse);
  });

  test('attention takes precedence over success', () {
    final decision = BackgroundSyncNotificationDecision.evaluate(
      successNotificationsEnabled: true,
      attentionNotificationsEnabled: true,
      completedOperations: 1,
      exhaustedOperations: 1,
      pendingConflicts: 2,
    );

    expect(decision.showSuccess, isFalse);
    expect(decision.showAttention, isTrue);
  });

  test('disabled notification preferences are respected', () {
    final decision = BackgroundSyncNotificationDecision.evaluate(
      successNotificationsEnabled: false,
      attentionNotificationsEnabled: false,
      completedOperations: 4,
      exhaustedOperations: 1,
      pendingConflicts: 1,
    );

    expect(decision.showSuccess, isFalse);
    expect(decision.showAttention, isFalse);
  });
}
