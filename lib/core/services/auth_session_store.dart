import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/account_profile.dart';
import 'firebase_push_notification_service.dart';
import 'supabase_service.dart';

class AuthSessionStore extends ChangeNotifier with WidgetsBindingObserver {
  AuthSessionStore._();

  static final AuthSessionStore instance = AuthSessionStore._();

  StreamSubscription<AuthState>? _authSubscription;
  Session? _session;
  Object? _lastError;
  AccountProfile? _accountProfile;
  bool _isRefreshingAccountProfile = false;
  String? _refreshingAccountProfileUserId;
  DateTime? _lastAccountProfileRefreshAt;
  bool _initialized = false;

  Session? get session => _session;

  User? get user => _session?.user;

  bool get isAuthenticated => user != null;

  AccountProfile? get accountProfile => _accountProfile;

  bool get isAccountProfileRefreshing => _isRefreshingAccountProfile;

  bool get isAccountBlocked =>
      _accountProfile != null && !_accountProfile!.canUseAccount;

  Object? get lastError => _lastError;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    if (!SupabaseService.isInitialized) {
      return;
    }

    _session = SupabaseService.client.auth.currentSession;
    WidgetsBinding.instance.addObserver(this);
    if (_session?.user != null) {
      unawaited(refreshAccountProfile(force: true));
    }

    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
      (authState) {
        final previousUserId = _session?.user.id;
        _session = authState.session;
        _lastError = null;
        final currentUserId = _session?.user.id;
        if (previousUserId != currentUserId) {
          _accountProfile = null;
          _lastAccountProfileRefreshAt = null;
          _isRefreshingAccountProfile = false;
          _refreshingAccountProfileUserId = null;
        }
        notifyListeners();
        if (currentUserId != null) {
          unawaited(refreshAccountProfile(force: true));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _lastError = error;
        debugPrint(
          'Supabase auth stream error: $error\n$stackTrace',
        );
        notifyListeners();
      },
    );
  }

  Future<AccountProfile?> refreshAccountProfile({bool force = false}) async {
    if (!SupabaseService.isInitialized || !isAuthenticated) {
      if (_accountProfile != null) {
        _accountProfile = null;
        notifyListeners();
      }
      return null;
    }

    final currentUser = user;
    if (currentUser == null) {
      return null;
    }

    final requestedUserId = currentUser.id;

    if (_isRefreshingAccountProfile &&
        _refreshingAccountProfileUserId == requestedUserId) {
      return _accountProfile;
    }

    final now = DateTime.now().toUtc();
    if (!force && _lastAccountProfileRefreshAt != null) {
      final age = now.difference(_lastAccountProfileRefreshAt!);
      if (age < const Duration(seconds: 20)) {
        return _accountProfile;
      }
    }

    _isRefreshingAccountProfile = true;
    _refreshingAccountProfileUserId = requestedUserId;
    notifyListeners();

    try {
      final rows = await SupabaseService.client
          .from('profiles')
          .select(
            'id, full_name, email, phone, avatar_url, role, is_active, '
            'deleted_at, suspension_reason',
          )
          .eq('id', requestedUserId)
          .limit(1);

      if (user?.id != requestedUserId) {
        return _accountProfile;
      }

      if (rows.isEmpty) {
        return _accountProfile;
      }

      final profile = AccountProfile.fromMap(rows.first);
      if (profile.id != requestedUserId || user?.id != requestedUserId) {
        return _accountProfile;
      }

      _accountProfile = profile;
      _lastAccountProfileRefreshAt = now;
      return profile;
    } catch (error) {
      if (user?.id == requestedUserId) {
        _lastError = error;
        debugPrint('Account access refresh failed: $error');
      }
      return _accountProfile;
    } finally {
      if (_refreshingAccountProfileUserId == requestedUserId) {
        _isRefreshingAccountProfile = false;
        _refreshingAccountProfileUserId = null;
        notifyListeners();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isAuthenticated) {
      unawaited(refreshAccountProfile(force: true));
    }
  }

  Future<void> signOut() async {
    if (!SupabaseService.isInitialized) {
      return;
    }

    await FirebasePushNotificationService.instance.unregisterCurrentToken();
    await SupabaseService.client.auth.signOut();
    _session = null;
    _accountProfile = null;
    _lastAccountProfileRefreshAt = null;
    _isRefreshingAccountProfile = false;
    _refreshingAccountProfileUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    super.dispose();
  }
}
