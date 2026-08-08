import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/app_preferences_store.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/firebase_push_notification_service.dart';
import '../../core/theme/app_text_styles.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  final AppPreferencesStore _preferences = AppPreferencesStore.instance;
  final FirebasePushNotificationService _pushService =
      FirebasePushNotificationService.instance;
  final AppUpdateService _updateService = AppUpdateService();

  AuthorizationStatus? _authorizationStatus;
  AppUpdateCheckResult? _updateResult;
  String _currentVersionLabel = '...';
  String? _updateErrorMessage;
  bool _isUpdatingPush = false;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _preferences.addListener(_handlePreferencesChanged);
    _refreshNotificationStatus();
    _loadCurrentVersionLabel();
  }

  @override
  void dispose() {
    _preferences.removeListener(_handlePreferencesChanged);
    _updateService.dispose();
    super.dispose();
  }

  void _handlePreferencesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshNotificationStatus() async {
    try {
      final settings = await _pushService.notificationSettings();
      if (mounted) {
        setState(() => _authorizationStatus = settings.authorizationStatus);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _authorizationStatus = null);
      }
    }
  }

  Future<void> _loadCurrentVersionLabel() async {
    try {
      final version = await _updateService.currentVersionLabel();
      if (mounted) {
        setState(() => _currentVersionLabel = version);
      }
    } catch (_) {
      // Version display is non-critical. Startup update checks run on SplashScreen.
    }
  }

  Future<void> _checkForUpdates({required bool showNoUpdateMessage}) async {
    if (_isCheckingUpdate) {
      return;
    }

    setState(() {
      _isCheckingUpdate = true;
      _updateErrorMessage = null;
    });

    try {
      final result = await _updateService.checkForUpdate();
      if (!mounted) {
        return;
      }

      setState(() {
        _updateResult = result;
        _currentVersionLabel = result.currentVersionLabel;
      });

      if (showNoUpdateMessage && !result.hasUpdate) {
        _showMessage(
          AppLocaleText.pick(
            context,
            ar: 'لديك أحدث إصدار متاح حاليًا.',
            en: 'You already have the latest available version.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _updateErrorMessage = AppLocaleText.pick(
          context,
          ar: 'تعذر التحقق من التحديثات. تحقق من اتصال الإنترنت ثم أعد المحاولة.',
          en: 'Could not check for updates. Check your internet connection and try again.',
        );
      });
      if (showNoUpdateMessage) {
        _showMessage(_updateErrorMessage!, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  Future<void> _downloadAvailableUpdate() async {
    final release = _updateResult?.availableRelease;
    if (release == null) {
      return;
    }

    final launched = await launchUrl(
      release.preferredDownloadUri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) {
      return;
    }
    if (!launched) {
      _showMessage(
        AppLocaleText.pick(
          context,
          ar: 'تعذر فتح رابط تنزيل التحديث.',
          en: 'Could not open the update download link.',
        ),
        isError: true,
      );
    }
  }

  String _updateStatusLabel(BuildContext context) {
    if (_updateErrorMessage != null) {
      return _updateErrorMessage!;
    }
    if (_isCheckingUpdate && _updateResult == null) {
      return AppLocaleText.pick(
        context,
        ar: 'جارٍ البحث عن إصدار أحدث…',
        en: 'Checking for a newer release…',
      );
    }

    final release = _updateResult?.availableRelease;
    if (release != null) {
      return AppLocaleText.pick(
        context,
        ar: 'يتوفر تحديث جديد: ${release.version.normalized}',
        en: 'New update available: ${release.version.normalized}',
      );
    }

    if (_updateResult != null) {
      return AppLocaleText.pick(
        context,
        ar: 'لديك أحدث إصدار متاح حاليًا.',
        en: 'You have the latest available version.',
      );
    }

    return AppLocaleText.pick(
      context,
      ar: 'يمكنك التحقق من الإصدارات المنشورة في مستودع التطبيق.',
      en: 'Check the releases published in the app repository.',
    );
  }

  Future<void> _setPublicNotifications(bool value) async {
    if (_isUpdatingPush) {
      return;
    }

    final previous = _preferences.snapshot.publicNotificationsEnabled;
    setState(() => _isUpdatingPush = true);

    try {
      await _preferences.setPublicNotificationsEnabled(value);
      await _pushService.applyPublicTopicPreference(value);
      await _refreshNotificationStatus();
      if (mounted) {
        _showMessage(
          value
              ? 'تم تفعيل الإشعارات العامة.'
              : 'تم إيقاف الإشعارات العامة على هذا الجهاز.',
        );
      }
    } catch (_) {
      await _preferences.setPublicNotificationsEnabled(previous);
      if (mounted) {
        _showMessage(
          'تعذر تحديث إعداد الإشعارات. حاول مرة أخرى.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPush = false);
      }
    }
  }

  Future<void> _resetPreferences() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استعادة الإعدادات'),
        content: const Text(
          'سيتم إعادة المظهر وحجم الخط والإشعارات العامة واللغة إلى القيم الافتراضية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _preferences.resetUserFacingPreferences();
    try {
      await _pushService.applyPublicTopicPreference(true);
    } catch (_) {
      // The local reset remains valid even when FCM is temporarily unavailable.
    }
    await _refreshNotificationStatus();
    if (mounted) {
      _showMessage('تمت استعادة الإعدادات الافتراضية.');
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final snapshot = _preferences.snapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات التطبيق'),
      ),
      body: ListView(
        key: const ValueKey<String>('app-settings-list'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          _SettingsSection(
            title: 'المظهر',
            icon: Icons.palette_outlined,
            child: Column(
              children: [
                _ThemeModeTile(
                  keyName: 'settings-theme-system',
                  title: 'حسب إعداد الجهاز',
                  subtitle: 'يتبع الوضع الفاتح أو الداكن في Android',
                  icon: Icons.brightness_auto_rounded,
                  selected:
                      snapshot.themeModePreset == AppThemeModePreset.system,
                  onTap: () => _preferences.setThemeModePreset(
                    AppThemeModePreset.system,
                  ),
                ),
                const Divider(height: 1),
                _ThemeModeTile(
                  keyName: 'settings-theme-light',
                  title: 'الوضع الفاتح',
                  subtitle: 'استخدام الألوان الفاتحة دائمًا',
                  icon: Icons.light_mode_outlined,
                  selected:
                      snapshot.themeModePreset == AppThemeModePreset.light,
                  onTap: () => _preferences.setThemeModePreset(
                    AppThemeModePreset.light,
                  ),
                ),
                const Divider(height: 1),
                _ThemeModeTile(
                  keyName: 'settings-theme-dark',
                  title: 'الوضع الداكن',
                  subtitle: 'واجهة داكنة مريحة للاستخدام الليلي',
                  icon: Icons.dark_mode_outlined,
                  selected: snapshot.themeModePreset == AppThemeModePreset.dark,
                  onTap: () => _preferences.setThemeModePreset(
                    AppThemeModePreset.dark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsSection(
            title: 'العرض',
            icon: Icons.text_fields_rounded,
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey<String>('settings-text-scale-normal'),
                  onTap: () => _preferences.setTextScalePreset(
                    AppTextScalePreset.normal,
                  ),
                  leading: const Icon(Icons.text_fields_rounded),
                  title: const Text('حجم خط عادي'),
                  subtitle: const Text('الحجم الافتراضي المتوازن للتطبيق'),
                  trailing:
                      snapshot.textScalePreset == AppTextScalePreset.normal
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primaryTeal,
                            )
                          : const Icon(Icons.circle_outlined),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey<String>('settings-text-scale-large'),
                  onTap: () => _preferences.setTextScalePreset(
                    AppTextScalePreset.large,
                  ),
                  leading: const Icon(Icons.format_size_rounded),
                  title: const Text('حجم خط كبير'),
                  subtitle: const Text('تكبير مريح للنصوص مع حد آمن للتخطيط'),
                  trailing: snapshot.textScalePreset == AppTextScalePreset.large
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryTeal,
                        )
                      : const Icon(Icons.circle_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsSection(
            title: 'اللغة',
            icon: Icons.language_rounded,
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey<String>('settings-language-ar'),
                  onTap: () => _preferences.setLocaleCode('ar'),
                  leading: const Icon(Icons.language_rounded),
                  title: const Text('العربية'),
                  subtitle: const Text('واجهة عربية من اليمين إلى اليسار'),
                  trailing: snapshot.localeCode == 'ar'
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryTeal,
                        )
                      : const Icon(Icons.circle_outlined),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey<String>('settings-language-en'),
                  onTap: () => _preferences.setLocaleCode('en'),
                  leading: const Icon(Icons.translate_rounded),
                  title: const Text('English'),
                  subtitle: const Text('واجهة إنجليزية من اليسار إلى اليمين'),
                  trailing: snapshot.localeCode == 'en'
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryTeal,
                        )
                      : const Icon(Icons.circle_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsSection(
            title: 'الإشعارات',
            icon: Icons.notifications_active_outlined,
            child: Column(
              children: [
                SwitchListTile(
                  key: const ValueKey<String>(
                    'settings-public-notifications-switch',
                  ),
                  value: snapshot.publicNotificationsEnabled,
                  onChanged: _isUpdatingPush ? null : _setPublicNotifications,
                  title: const Text('الإشعارات العامة'),
                  subtitle: const Text(
                    'استقبال التنبيهات العامة التي ترسلها إدارة دليل الحامي',
                  ),
                  secondary: _isUpdatingPush
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.campaign_outlined),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey<String>(
                    'settings-notification-permission-status',
                  ),
                  leading: const Icon(Icons.security_rounded),
                  title: const Text('إذن إشعارات Android'),
                  subtitle: Text(_permissionLabel(_authorizationStatus)),
                  trailing: IconButton(
                    tooltip: AppLocaleText.pick(context,
                        ar: 'تحديث الحالة', en: 'Refresh status'),
                    onPressed: _refreshNotificationStatus,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsSection(
            title: 'التحديثات',
            icon: Icons.system_update_alt_rounded,
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey<String>('settings-check-updates'),
                  onTap: _isCheckingUpdate
                      ? null
                      : () => _checkForUpdates(showNoUpdateMessage: true),
                  leading: _isCheckingUpdate
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  title: const Text('التحقق من التحديثات'),
                  subtitle: Text(_updateStatusLabel(context)),
                  trailing: _isCheckingUpdate
                      ? null
                      : const Icon(Icons.chevron_right_rounded),
                ),
                if (_updateResult?.hasUpdate == true) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey<String>(
                          'settings-download-update',
                        ),
                        onPressed: _downloadAvailableUpdate,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('تنزيل التحديث'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsSection(
            title: 'حول التطبيق',
            icon: Icons.info_outline_rounded,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.apps_rounded),
                  title: Text('دليل الحامي'),
                  subtitle: Text('دليل الخدمات والأنشطة المحلية'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey<String>('settings-app-version'),
                  leading: const Icon(Icons.tag_rounded),
                  title: const Text('الإصدار'),
                  subtitle: Text(_currentVersionLabel),
                ),
                const Divider(height: 1),
                const ListTile(
                  key: ValueKey<String>('settings-app-idea-credit'),
                  leading: Icon(Icons.lightbulb_outline_rounded),
                  title: Text('فكرة التطبيق'),
                  subtitle: Text('الغريم سالم'),
                ),
                const Divider(height: 1),
                const ListTile(
                  key: ValueKey<String>('settings-app-development-credit'),
                  leading: Icon(Icons.code_rounded),
                  title: Text('برمجة وتطوير'),
                  subtitle: Text('المهندس عوض بن قفلة'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            key: const ValueKey<String>('settings-reset-defaults'),
            onPressed: _resetPreferences,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('استعادة الإعدادات الافتراضية'),
          ),
        ],
      ),
    );
  }

  String _permissionLabel(AuthorizationStatus? status) {
    return switch (status) {
      AuthorizationStatus.authorized => 'مسموح',
      AuthorizationStatus.provisional => 'مسموح مؤقتًا',
      AuthorizationStatus.denied => 'غير مسموح من إعدادات Android',
      AuthorizationStatus.notDetermined => 'لم يتم تحديد الإذن بعد',
      null => 'تعذر قراءة حالة الإذن حاليًا',
    };
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.keyName,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String keyName;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return ListTile(
      key: ValueKey<String>(keyName),
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected
          ? const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primaryTeal,
            )
          : const Icon(Icons.circle_outlined),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.primarySoft,
            child: Row(
              children: [
                const SizedBox(width: 0),
                Icon(icon, color: AppColors.primaryTeal),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: AppTextStyles.titleSmall),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
