import 'package:flutter/material.dart';
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

enum AppThemeModePreset {
  system,
  light,
  dark,
}

extension AppThemeModePresetValue on AppThemeModePreset {
  String get storageValue => name;

  ThemeMode get materialThemeMode => switch (this) {
        AppThemeModePreset.system => ThemeMode.system,
        AppThemeModePreset.light => ThemeMode.light,
        AppThemeModePreset.dark => ThemeMode.dark,
      };
}

class AppPreferencesSnapshot {
  const AppPreferencesSnapshot({
    this.localeCode = 'ar',
    this.textScalePreset = AppTextScalePreset.normal,
    this.themeModePreset = AppThemeModePreset.system,
    this.publicNotificationsEnabled = true,
  });

  final String localeCode;
  final AppTextScalePreset textScalePreset;
  final AppThemeModePreset themeModePreset;
  final bool publicNotificationsEnabled;

  double get textScaleFactor => textScalePreset.factor;

  AppPreferencesSnapshot copyWith({
    String? localeCode,
    AppTextScalePreset? textScalePreset,
    AppThemeModePreset? themeModePreset,
    bool? publicNotificationsEnabled,
  }) {
    return AppPreferencesSnapshot(
      localeCode: localeCode ?? this.localeCode,
      textScalePreset: textScalePreset ?? this.textScalePreset,
      themeModePreset: themeModePreset ?? this.themeModePreset,
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
  static const String themeModeKey = 'phase11b_theme_mode_v1';
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

  Future<void> setThemeModePreset(AppThemeModePreset preset) async {
    if (!_initialized) {
      await initialize();
    }
    if (_snapshot.themeModePreset == preset) {
      return;
    }

    // Update the in-memory preference first so the UI reacts in the same frame.
    // Persistence happens afterwards and must never block the visible theme switch.
    _snapshot = _snapshot.copyWith(themeModePreset: preset);
    notifyListeners();

    await _preferences!.setString(themeModeKey, preset.storageValue);
  }

  Future<void> setLocaleCode(String value) async {
    final normalized = value.trim().toLowerCase();
    if (normalized != 'ar' && normalized != 'en') {
      throw ArgumentError.value(value, 'value', 'Unsupported locale code.');
    }

    if (!_initialized) {
      await initialize();
    }
    if (_snapshot.localeCode == normalized) {
      return;
    }

    // Mirror the instant theme-switch contract: visible locale/direction changes
    // must not wait for SharedPreferences I/O.
    _snapshot = _snapshot.copyWith(localeCode: normalized);
    notifyListeners();

    await _preferences!.setString(localeKey, normalized);
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
    await preferences.remove(themeModeKey);
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
    final rawLocale = preferences.getString(localeKey)?.trim().toLowerCase();
    final safeLocale = rawLocale == 'en' ? 'en' : 'ar';

    final rawScale = preferences.getString(textScaleKey);
    final scale = AppTextScalePreset.values.firstWhere(
      (value) => value.storageValue == rawScale,
      orElse: () => AppTextScalePreset.normal,
    );

    final rawThemeMode = preferences.getString(themeModeKey);
    final themeMode = AppThemeModePreset.values.firstWhere(
      (value) => value.storageValue == rawThemeMode,
      orElse: () => AppThemeModePreset.system,
    );

    return AppPreferencesSnapshot(
      localeCode: safeLocale,
      textScalePreset: scale,
      themeModePreset: themeMode,
      publicNotificationsEnabled:
          preferences.getBool(publicNotificationsKey) ?? true,
    );
  }
}
