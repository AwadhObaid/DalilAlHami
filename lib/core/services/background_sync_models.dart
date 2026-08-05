class BackgroundSyncSettingsSnapshot {
  const BackgroundSyncSettingsSnapshot({
    this.backgroundSyncEnabled = true,
    this.successNotificationsEnabled = true,
    this.attentionNotificationsEnabled = true,
    this.notificationPermissionGranted,
    this.lastRunAt,
    this.lastRunStatus,
    this.lastRunMessage,
  });

  final bool backgroundSyncEnabled;
  final bool successNotificationsEnabled;
  final bool attentionNotificationsEnabled;
  final bool? notificationPermissionGranted;
  final DateTime? lastRunAt;
  final String? lastRunStatus;
  final String? lastRunMessage;

  BackgroundSyncSettingsSnapshot copyWith({
    bool? backgroundSyncEnabled,
    bool? successNotificationsEnabled,
    bool? attentionNotificationsEnabled,
    bool? notificationPermissionGranted,
    bool clearNotificationPermission = false,
    DateTime? lastRunAt,
    String? lastRunStatus,
    String? lastRunMessage,
  }) {
    return BackgroundSyncSettingsSnapshot(
      backgroundSyncEnabled:
          backgroundSyncEnabled ?? this.backgroundSyncEnabled,
      successNotificationsEnabled:
          successNotificationsEnabled ?? this.successNotificationsEnabled,
      attentionNotificationsEnabled:
          attentionNotificationsEnabled ?? this.attentionNotificationsEnabled,
      notificationPermissionGranted: clearNotificationPermission
          ? null
          : notificationPermissionGranted ?? this.notificationPermissionGranted,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      lastRunStatus: lastRunStatus ?? this.lastRunStatus,
      lastRunMessage: lastRunMessage ?? this.lastRunMessage,
    );
  }

  String get lastRunLabel {
    final value = lastRunAt?.toLocal();
    if (value == null) {
      return 'لم تعمل المزامنة في الخلفية بعد.';
    }

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(value.day)}/${twoDigits(value.month)}/'
        '${value.year} ${twoDigits(value.hour)}:'
        '${twoDigits(value.minute)}';
  }
}

class BackgroundSyncWorkerSettings {
  const BackgroundSyncWorkerSettings({
    required this.backgroundSyncEnabled,
    required this.successNotificationsEnabled,
    required this.attentionNotificationsEnabled,
  });

  final bool backgroundSyncEnabled;
  final bool successNotificationsEnabled;
  final bool attentionNotificationsEnabled;
}

class BackgroundSyncNotificationDecision {
  const BackgroundSyncNotificationDecision({
    required this.showSuccess,
    required this.showAttention,
  });

  final bool showSuccess;
  final bool showAttention;

  static BackgroundSyncNotificationDecision evaluate({
    required bool successNotificationsEnabled,
    required bool attentionNotificationsEnabled,
    required int completedOperations,
    required int exhaustedOperations,
    required int pendingConflicts,
  }) {
    final needsAttention = exhaustedOperations > 0 || pendingConflicts > 0;

    return BackgroundSyncNotificationDecision(
      showSuccess: successNotificationsEnabled &&
          completedOperations > 0 &&
          !needsAttention,
      showAttention: attentionNotificationsEnabled && needsAttention,
    );
  }
}
