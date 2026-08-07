import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/push_device_repository.dart';
import '../../firebase_options.dart';
import 'background_notification_service.dart';
import 'push_notification_navigation_service.dart';
import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class FirebasePushNotificationService {
  FirebasePushNotificationService._();

  static final FirebasePushNotificationService instance =
      FirebasePushNotificationService._();

  static const String _permissionPromptedKey =
      'phase10a_fcm_permission_requested';
  static const String publicTopicName = 'dalil_alhami_public';

  final PushDeviceRepository _repository = const PushDeviceRepository();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  String? _lastKnownToken;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    BackgroundNotificationService.instance.setNotificationTapHandler(
      PushNotificationNavigationService.instance.handleLocalPayload,
    );

    await _messaging.setAutoInitEnabled(true);

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: _logStreamError,
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
      onError: _logStreamError,
    );
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      _handleTokenRefresh,
      onError: _logStreamError,
    );

    if (SupabaseService.isInitialized) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
        (state) {
          if (state.session != null) {
            unawaited(syncCurrentToken());
          }
        },
        onError: _logStreamError,
      );
    }

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }
  }

  void schedulePostLaunchRegistration() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_requestPermissionAndSync());
    });
  }

  Future<void> syncCurrentToken() async {
    if (Firebase.apps.isEmpty ||
        !SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentUser == null) {
      return;
    }

    try {
      final token = (await _messaging.getToken())?.trim();
      if (token == null || token.isEmpty) {
        return;
      }
      _lastKnownToken = token;
      await _repository.registerToken(
        token: token,
        platform: _platformName,
      );
    } catch (error, stackTrace) {
      debugPrint('FCM token sync failed: $error\n$stackTrace');
    }
  }

  Future<void> unregisterCurrentToken() async {
    if (Firebase.apps.isEmpty ||
        !SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentUser == null) {
      return;
    }

    try {
      final token = _lastKnownToken ?? (await _messaging.getToken())?.trim();
      if (token == null || token.isEmpty) {
        return;
      }
      await _repository.unregisterToken(token);
    } catch (error, stackTrace) {
      debugPrint('FCM token unregister failed: $error\n$stackTrace');
    }
  }

  Future<void> _requestPermissionAndSync() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final wasPrompted = preferences.getBool(_permissionPromptedKey) ?? false;

      final NotificationSettings settings;
      if (wasPrompted) {
        settings = await _messaging.getNotificationSettings();
      } else {
        settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        await preferences.setBool(_permissionPromptedKey, true);
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _messaging.subscribeToTopic(publicTopicName);
        await syncCurrentToken();
      }
    } catch (error, stackTrace) {
      debugPrint('FCM permission setup failed: $error\n$stackTrace');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();

    if ((title?.trim().isEmpty ?? true) && (body?.trim().isEmpty ?? true)) {
      return;
    }

    final rawId = message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch.remainder(1000000000);
    final notificationId = rawId & 0x7fffffff;

    await BackgroundNotificationService.instance.showPush(
      notificationId: notificationId,
      title: title?.trim().isNotEmpty == true ? title!.trim() : 'دليل الحامي',
      body: body?.trim() ?? '',
      data: message.data,
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    PushNotificationNavigationService.instance.handleData(message.data);
  }

  Future<void> _handleTokenRefresh(String token) async {
    final safeToken = token.trim();
    if (safeToken.isEmpty) {
      return;
    }
    _lastKnownToken = safeToken;

    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentUser == null) {
      return;
    }

    try {
      await _repository.registerToken(
        token: safeToken,
        platform: _platformName,
      );
    } catch (error, stackTrace) {
      debugPrint('FCM refreshed token sync failed: $error\n$stackTrace');
    }
  }

  void _logStreamError(Object error, StackTrace stackTrace) {
    debugPrint('FCM stream error: $error\n$stackTrace');
  }

  String get _platformName {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
  }
}
