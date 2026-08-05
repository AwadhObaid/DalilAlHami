import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_sync_models.dart';

class BackgroundSyncSettingsStore extends ChangeNotifier {
  BackgroundSyncSettingsStore._();

  static final BackgroundSyncSettingsStore instance =
      BackgroundSyncSettingsStore._();

  static const String _enabledKey = 'background_sync_enabled_v1';
  static const String _successNotificationsKey =
      'background_sync_success_notifications_v1';
  static const String _attentionNotificationsKey =
      'background_sync_attention_notifications_v1';
  static const String _permissionGrantedKey =
      'background_sync_notification_permission_v1';
  static const String _lastRunAtKey = 'background_sync_last_run_at_v1';
  static const String _lastRunStatusKey = 'background_sync_last_run_status_v1';
  static const String _lastRunMessageKey =
      'background_sync_last_run_message_v1';
  static const String _lastSuccessSignatureKey =
      'background_sync_last_success_signature_v1';
  static const String _lastAttentionSignatureKey =
      'background_sync_last_attention_signature_v1';

  SharedPreferences? _preferences;
  BackgroundSyncSettingsSnapshot _snapshot =
      const BackgroundSyncSettingsSnapshot();
  bool _initialized = false;

  BackgroundSyncSettingsSnapshot get snapshot => _snapshot;
  bool get isInitialized => _initialized;

  Future<void> initialize({bool reload = false}) async {
    _preferences ??= await SharedPreferences.getInstance();
    if (reload) {
      await _preferences!.reload();
    }

    _snapshot = _readSnapshot(_preferences!);
    _initialized = true;
    notifyListeners();
  }

  Future<void> reload() => initialize(reload: true);

  Future<void> setBackgroundSyncEnabled(bool value) async {
    final preferences = await _ensurePreferences();
    await preferences.setBool(_enabledKey, value);
    _snapshot = _snapshot.copyWith(backgroundSyncEnabled: value);
    notifyListeners();
  }

  Future<void> setSuccessNotificationsEnabled(bool value) async {
    final preferences = await _ensurePreferences();
    await preferences.setBool(_successNotificationsKey, value);
    _snapshot = _snapshot.copyWith(
      successNotificationsEnabled: value,
    );
    notifyListeners();
  }

  Future<void> setAttentionNotificationsEnabled(bool value) async {
    final preferences = await _ensurePreferences();
    await preferences.setBool(_attentionNotificationsKey, value);
    _snapshot = _snapshot.copyWith(
      attentionNotificationsEnabled: value,
    );
    notifyListeners();
  }

  Future<void> setNotificationPermissionGranted(bool value) async {
    final preferences = await _ensurePreferences();
    await preferences.setBool(_permissionGrantedKey, value);
    _snapshot = _snapshot.copyWith(
      notificationPermissionGranted: value,
    );
    notifyListeners();
  }

  Future<SharedPreferences> _ensurePreferences() async {
    if (!_initialized) {
      await initialize();
    }
    return _preferences!;
  }

  static Future<BackgroundSyncWorkerSettings> readWorkerSettings() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();

    return BackgroundSyncWorkerSettings(
      backgroundSyncEnabled: preferences.getBool(_enabledKey) ?? true,
      successNotificationsEnabled:
          preferences.getBool(_successNotificationsKey) ?? true,
      attentionNotificationsEnabled:
          preferences.getBool(_attentionNotificationsKey) ?? true,
    );
  }

  static Future<void> recordWorkerRun({
    required String status,
    required String message,
    DateTime? completedAt,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final timestamp = (completedAt ?? DateTime.now()).toUtc();

    await preferences.setString(
      _lastRunAtKey,
      timestamp.toIso8601String(),
    );
    await preferences.setString(_lastRunStatusKey, status);
    await preferences.setString(_lastRunMessageKey, message);
  }

  static Future<bool> claimNotification({
    required String signature,
    required bool attention,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final key =
        attention ? _lastAttentionSignatureKey : _lastSuccessSignatureKey;
    final previous = preferences.getString(key);
    if (previous == signature) {
      return false;
    }

    await preferences.setString(key, signature);
    return true;
  }

  static Future<void> clearAttentionNotificationSignature() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_lastAttentionSignatureKey);
  }

  static BackgroundSyncSettingsSnapshot _readSnapshot(
    SharedPreferences preferences,
  ) {
    DateTime? parseDate(String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }
      return DateTime.tryParse(value)?.toUtc();
    }

    return BackgroundSyncSettingsSnapshot(
      backgroundSyncEnabled: preferences.getBool(_enabledKey) ?? true,
      successNotificationsEnabled:
          preferences.getBool(_successNotificationsKey) ?? true,
      attentionNotificationsEnabled:
          preferences.getBool(_attentionNotificationsKey) ?? true,
      notificationPermissionGranted:
          preferences.containsKey(_permissionGrantedKey)
              ? preferences.getBool(_permissionGrantedKey)
              : null,
      lastRunAt: parseDate(preferences.getString(_lastRunAtKey)),
      lastRunStatus: preferences.getString(_lastRunStatusKey),
      lastRunMessage: preferences.getString(_lastRunMessageKey),
    );
  }
}
