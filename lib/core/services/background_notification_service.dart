import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef NotificationTapHandler = void Function(String? payload);

class BackgroundNotificationService {
  BackgroundNotificationService._();

  static final BackgroundNotificationService instance =
      BackgroundNotificationService._();

  static const String channelId = 'dalil_alhami_background_sync';
  static const String channelName = 'مزامنة دليل الحامي';
  static const String channelDescription =
      'نتائج المزامنة والعمليات التي تحتاج إلى تدخل.';

  static const String pushChannelId = 'dalil_alhami_push';
  static const String pushChannelName = 'إشعارات دليل الحامي';
  static const String pushChannelDescription =
      'التنبيهات والإشعارات المرسلة من دليل الحامي.';

  static const int successNotificationId = 5101;
  static const int attentionNotificationId = 5102;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  NotificationTapHandler? _notificationTapHandler;
  bool _initialized = false;

  void setNotificationTapHandler(NotificationTapHandler? handler) {
    _notificationTapHandler = handler;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const android = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _notificationTapHandler?.call(response.payload);
      },
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        pushChannelId,
        pushChannelName,
        description: pushChannelDescription,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final result = await android?.requestNotificationsPermission();
    return result ?? true;
  }

  Future<void> showPush({
    required int notificationId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    await initialize();
    const android = AndroidNotificationDetails(
      pushChannelId,
      pushChannelName,
      channelDescription: pushChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      category: AndroidNotificationCategory.message,
    );
    const details = NotificationDetails(android: android);

    await _plugin.show(
      notificationId,
      title,
      body,
      details,
      payload: jsonEncode(data),
    );
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
