import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/directory_data_store.dart';
import 'auth_session_store.dart';
import 'background_notification_service.dart';
import 'background_sync_models.dart';
import 'background_sync_settings.dart';
import 'supabase_service.dart';

const String backgroundSyncTaskName = 'dalil_alhami_background_sync_task';
const String backgroundSyncPeriodicUniqueName =
    'dalil_alhami_periodic_background_sync_v1';
const String backgroundSyncOneOffUniqueName =
    'dalil_alhami_one_off_background_sync_v1';
const String backgroundSyncTaskTag = 'dalil_alhami_background_sync';

@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (task != backgroundSyncTaskName) {
      return true;
    }

    final settings = await BackgroundSyncSettingsStore.readWorkerSettings();
    if (!settings.backgroundSyncEnabled) {
      await BackgroundSyncSettingsStore.recordWorkerRun(
        status: 'disabled',
        message: 'المزامنة في الخلفية متوقفة من الإعدادات.',
      );
      return true;
    }

    try {
      await SupabaseService.initializeIfConfigured();
      await AuthSessionStore.instance.initialize();

      if (!SupabaseService.isInitialized ||
          !AuthSessionStore.instance.isAuthenticated) {
        await BackgroundSyncSettingsStore.recordWorkerRun(
          status: 'signed_out',
          message: 'تم تجاوز المزامنة لعدم وجود جلسة دخول نشطة.',
        );
        return true;
      }

      final report = await DirectoryDataStore.instance.runBackgroundSync();
      await _handleBackgroundNotifications(
        settings: settings,
        report: report,
      );

      final status = report.needsAttention
          ? 'attention'
          : report.hasTransientFailure
              ? 'retry'
              : 'success';
      final message = report.needsAttention
          ? 'توجد عمليات أو تعارضات تحتاج إلى تدخل.'
          : report.hasTransientFailure
              ? 'تعذرت المزامنة وستعيدها Android لاحقًا.'
              : report.completedOperations > 0
                  ? 'اكتملت مزامنة ${report.completedOperations} عملية.'
                  : 'تم فحص المزامنة ولا توجد عمليات معلقة.';

      await BackgroundSyncSettingsStore.recordWorkerRun(
        status: status,
        message: message,
      );

      return report.needsAttention || !report.hasTransientFailure;
    } catch (error, stackTrace) {
      debugPrint('Background sync worker failed: $error\n$stackTrace');
      await BackgroundSyncSettingsStore.recordWorkerRun(
        status: 'retry',
        message: 'فشل تشغيل المزامنة في الخلفية وستتم إعادة المحاولة.',
      );
      return false;
    }
  });
}

Future<void> _handleBackgroundNotifications({
  required BackgroundSyncWorkerSettings settings,
  required DirectoryBackgroundSyncReport report,
}) async {
  final decision = BackgroundSyncNotificationDecision.evaluate(
    successNotificationsEnabled: settings.successNotificationsEnabled,
    attentionNotificationsEnabled: settings.attentionNotificationsEnabled,
    completedOperations: report.completedOperations,
    exhaustedOperations: report.exhaustedOperations,
    pendingConflicts: report.pendingConflicts,
  );

  if (decision.showAttention) {
    final signature = 'attention:'
        '${report.exhaustedOperations}:'
        '${report.pendingConflicts}';
    final claimed = await BackgroundSyncSettingsStore.claimNotification(
      signature: signature,
      attention: true,
    );
    if (claimed) {
      await BackgroundNotificationService.instance.showAttention(
        exhaustedOperations: report.exhaustedOperations,
        pendingConflicts: report.pendingConflicts,
      );
    }
    return;
  }

  if (!report.needsAttention) {
    await BackgroundSyncSettingsStore.clearAttentionNotificationSignature();
    await BackgroundNotificationService.instance.cancelAttentionNotification();
  }

  if (decision.showSuccess) {
    final signature = 'success:'
        '${report.completedOperations}:'
        '${DateTime.now().toUtc().millisecondsSinceEpoch ~/ 60000}';
    final claimed = await BackgroundSyncSettingsStore.claimNotification(
      signature: signature,
      attention: false,
    );
    if (claimed) {
      await BackgroundNotificationService.instance.showSuccess(
        completedOperations: report.completedOperations,
      );
    }
  }
}

class BackgroundSyncService {
  BackgroundSyncService._();

  static final BackgroundSyncService instance = BackgroundSyncService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await BackgroundSyncSettingsStore.instance.initialize();
    await BackgroundNotificationService.instance.initialize();
    await Workmanager().initialize(backgroundSyncCallbackDispatcher);
    _initialized = true;
    await applySchedule();
  }

  Future<void> applySchedule() async {
    if (!_initialized) {
      await initialize();
      return;
    }

    final enabled =
        BackgroundSyncSettingsStore.instance.snapshot.backgroundSyncEnabled;
    if (!enabled) {
      await Workmanager().cancelByUniqueName(
        backgroundSyncPeriodicUniqueName,
      );
      await Workmanager().cancelByUniqueName(
        backgroundSyncOneOffUniqueName,
      );
      return;
    }

    await Workmanager().registerPeriodicTask(
      backgroundSyncPeriodicUniqueName,
      backgroundSyncTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
      tag: backgroundSyncTaskTag,
    );
  }

  Future<void> scheduleOneOffSync({
    Duration initialDelay = const Duration(seconds: 5),
  }) async {
    if (!_initialized ||
        !BackgroundSyncSettingsStore.instance.snapshot.backgroundSyncEnabled) {
      return;
    }

    await Workmanager().registerOneOffTask(
      backgroundSyncOneOffUniqueName,
      backgroundSyncTaskName,
      initialDelay: initialDelay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 10),
      tag: backgroundSyncTaskTag,
    );
  }

  Future<bool> requestNotificationPermission() async {
    final granted =
        await BackgroundNotificationService.instance.requestPermission();
    await BackgroundSyncSettingsStore.instance
        .setNotificationPermissionGranted(granted);
    return granted;
  }
}
