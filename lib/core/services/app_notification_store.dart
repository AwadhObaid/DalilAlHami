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
  String? _activeUserId;
  String? _refreshingUserId;

  int get unreadCount => _unreadCount;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (!SupabaseService.isInitialized) {
      return;
    }

    _activeUserId = SupabaseService.client.auth.currentUser?.id;

    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
      (state) {
        final nextUserId = state.session?.user.id;
        if (_activeUserId != nextUserId) {
          _activeUserId = nextUserId;
          _setUnreadCount(0);
        }

        if (nextUserId != null) {
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
    if (!SupabaseService.isInitialized) {
      _activeUserId = null;
      _setUnreadCount(0);
      return;
    }

    final requestedUserId = SupabaseService.client.auth.currentUser?.id;
    if (requestedUserId == null) {
      _activeUserId = null;
      _setUnreadCount(0);
      return;
    }

    if (_activeUserId != requestedUserId) {
      _activeUserId = requestedUserId;
      _setUnreadCount(0);
    }

    if (_refreshing && _refreshingUserId == requestedUserId) {
      return;
    }

    _refreshing = true;
    _refreshingUserId = requestedUserId;

    try {
      final unread = await _repository.unreadCount();

      if (_activeUserId != requestedUserId ||
          SupabaseService.client.auth.currentUser?.id != requestedUserId) {
        return;
      }

      _setUnreadCount(unread);
    } catch (error, stackTrace) {
      if (_activeUserId == requestedUserId &&
          SupabaseService.client.auth.currentUser?.id == requestedUserId) {
        debugPrint('Notification unread refresh failed: $error\n$stackTrace');
      }
    } finally {
      if (_refreshingUserId == requestedUserId) {
        _refreshing = false;
        _refreshingUserId = null;
      }
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

  Future<bool> dismiss(String notificationId) async {
    final visible = await _repository.dismiss(notificationId);
    await refreshUnreadCount();
    return visible;
  }

  Future<int> dismissMany(List<String> notificationIds) async {
    final changed = await _repository.dismissMany(notificationIds);
    await refreshUnreadCount();
    return changed;
  }

  Future<int> dismissAll() async {
    final changed = await _repository.dismissAll();
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
