import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/notification_repository.dart';
import 'supabase_service.dart';

class AppNotificationStore extends ChangeNotifier {
  AppNotificationStore._();

  static final AppNotificationStore instance = AppNotificationStore._();

  final NotificationRepository _repository = const NotificationRepository();

  StreamSubscription<AuthState>? _authSubscription;
  int _unreadCount = 0;
  bool _initialized = false;
  bool _refreshing = false;

  int get unreadCount => _unreadCount;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (!SupabaseService.isInitialized) {
      return;
    }

    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
      (state) {
        if (state.session == null) {
          _setUnreadCount(0);
        } else {
          unawaited(refreshUnreadCount());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Notification auth stream error: $error\n$stackTrace');
      },
    );

    await refreshUnreadCount();
  }

  Future<void> refreshUnreadCount() async {
    if (_refreshing ||
        !SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentUser == null) {
      if (!SupabaseService.isInitialized ||
          SupabaseService.client.auth.currentUser == null) {
        _setUnreadCount(0);
      }
      return;
    }

    _refreshing = true;
    try {
      _setUnreadCount(await _repository.unreadCount());
    } catch (error, stackTrace) {
      debugPrint('Notification unread refresh failed: $error\n$stackTrace');
    } finally {
      _refreshing = false;
    }
  }

  Future<bool> markRead(String notificationId) async {
    final visible = await _repository.markRead(notificationId);
    if (visible) {
      await refreshUnreadCount();
    }
    return visible;
  }

  Future<int> markAllRead() async {
    final changed = await _repository.markAllRead();
    _setUnreadCount(0);
    return changed;
  }

  void notifyPushReceived() {
    unawaited(refreshUnreadCount());
  }

  void _setUnreadCount(int value) {
    final safeValue = value < 0 ? 0 : value;
    if (_unreadCount == safeValue) {
      return;
    }
    _unreadCount = safeValue;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
