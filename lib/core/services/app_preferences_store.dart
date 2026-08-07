import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing application preferences that are safe to keep locally.
enum AppTextScalePreset {
  normal,
  large,
}

extension AppTextScalePresetValue on AppTextScalePreset {
  double get factor => switch (this) {
        AppTextScalePreset.normal => 1.0,
        AppTextScalePreset.large => 1.12,
      };

  String get storageValue => name;
}

class AppPreferencesSnapshot {
  const AppPreferencesSnapshot({
    this.localeCode = 'ar',
    this.textScalePreset = AppTextScalePreset.normal,
    this.publicNotificationsEnabled = true,
  });

  final String localeCode;
  final AppTextScalePreset textScalePreset;
  final bool publicNotificationsEnabled;

  double get textScaleFactor => textScalePreset.factor;

  AppPreferencesSnapshot copyWith({
    String? localeCode,
    AppTextScalePreset? textScalePreset,
    bool? publicNotificationsEnabled,
  }) {
    return AppPreferencesSnapshot(
      localeCode: localeCode ?? this.localeCode,
      textScalePreset: textScalePreset ?? this.textScalePreset,
      publicNotificationsEnabled:
          publicNotificationsEnabled ?? this.publicNotificationsEnabled,
    );
  }
}

class AppPreferencesStore extends ChangeNotifier {
  AppPreferencesStore._();

  static final AppPreferencesStore instance = AppPreferencesStore._();

  static const String localeKey = 'app_locale_code_v1';
  static const String textScaleKey = 'app_text_scale_preset_v1';
  static const String publicNotificationsKey =
      'phase11_public_notifications_enabled_v1';

  SharedPreferences? _preferences;
  AppPreferencesSnapshot _snapshot = const AppPreferencesSnapshot();
  bool _initialized = false;

  AppPreferencesSnapshot get snapshot => _snapshot;
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

  Future<void> setTextScalePreset(AppTextScalePreset preset) async {
    final preferences = await _ensurePreferences();
    await preferences.setString(textScaleKey, preset.storageValue);
    _snapshot = _snapshot.copyWith(textScalePreset: preset);
    notifyListeners();
  }

  /// Phase 11A keeps Arabic as the production language while Phase 11B
  /// completes the full English translation. The persisted locale contract is
  /// already in place so the later rollout does not need another settings
  /// migration.
  Future<void> setLocaleCode(String value) async {
    final normalized = value.trim().toLowerCase();
    if (normalized != 'ar' && normalized != 'en') {
      throw ArgumentError.value(value, 'value', 'Unsupported locale code.');
    }

    final preferences = await _ensurePreferences();
    await preferences.setString(localeKey, normalized);
    _snapshot = _snapshot.copyWith(localeCode: normalized);
    notifyListeners();
  }

  Future<void> setPublicNotificationsEnabled(bool value) async {
    final preferences = await _ensurePreferences();
    await preferences.setBool(publicNotificationsKey, value);
    _snapshot = _snapshot.copyWith(publicNotificationsEnabled: value);
    notifyListeners();
  }

  Future<void> resetUserFacingPreferences() async {
    final preferences = await _ensurePreferences();
    await preferences.remove(localeKey);
    await preferences.remove(textScaleKey);
    await preferences.remove(publicNotificationsKey);
    _snapshot = const AppPreferencesSnapshot();
    notifyListeners();
  }

  Future<SharedPreferences> _ensurePreferences() async {
    if (!_initialized) {
      await initialize();
    }
    return _preferences!;
  }

  AppPreferencesSnapshot _readSnapshot(SharedPreferences preferences) {
    final locale = preferences.getString(localeKey)?.trim().toLowerCase();
    final safeLocale = locale == 'en' ? 'en' : 'ar';

    final rawScale = preferences.getString(textScaleKey);
    final scale = AppTextScalePreset.values.firstWhere(
      (value) => value.storageValue == rawScale,
      orElse: () => AppTextScalePreset.normal,
    );

    return AppPreferencesSnapshot(
      localeCode: safeLocale,
      textScalePreset: scale,
      publicNotificationsEnabled:
          preferences.getBool(publicNotificationsKey) ?? true,
    );
  }
}
