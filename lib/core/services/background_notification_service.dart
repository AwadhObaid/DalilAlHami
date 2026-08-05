import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BackgroundNotificationService {
  BackgroundNotificationService._();

  static final BackgroundNotificationService instance =
      BackgroundNotificationService._();

  static const String channelId = 'dalil_alhami_background_sync';
  static const String channelName = 'مزامنة دليل الحامي';
  static const String channelDescription =
      'نتائج المزامنة والعمليات التي تحتاج إلى تدخل.';

  static const int successNotificationId = 5101;
  static const int attentionNotificationId = 5102;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const android = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final result = await android?.requestNotificationsPermission();
    return result ?? true;
  }

  Future<void> showSuccess({
    required int completedOperations,
  }) async {
    await initialize();
    const android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/launcher_icon',
      category: AndroidNotificationCategory.status,
    );
    const details = NotificationDetails(android: android);

    await _plugin.show(
      successNotificationId,
      'اكتملت المزامنة',
      completedOperations == 1
          ? 'تم إرسال عملية واحدة محفوظة بنجاح.'
          : 'تم إرسال $completedOperations عمليات محفوظة بنجاح.',
      details,
      payload: 'sync-queue',
    );
  }

  Future<void> showAttention({
    required int exhaustedOperations,
    required int pendingConflicts,
  }) async {
    await initialize();
    const android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      category: AndroidNotificationCategory.error,
    );
    const details = NotificationDetails(android: android);

    final parts = <String>[];
    if (pendingConflicts > 0) {
      parts.add('$pendingConflicts تعارض يحتاج قرارًا');
    }
    if (exhaustedOperations > 0) {
      parts.add('$exhaustedOperations عملية متوقفة');
    }

    await _plugin.show(
      attentionNotificationId,
      'المزامنة تحتاج إلى تدخلك',
      parts.join('، '),
      details,
      payload: 'sync-queue',
    );
  }

  Future<void> cancelAttentionNotification() async {
    await initialize();
    await _plugin.cancel(attentionNotificationId);
  }
}
