import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AuthSessionStore extends ChangeNotifier {
  AuthSessionStore._();

  static final AuthSessionStore instance = AuthSessionStore._();

  StreamSubscription<AuthState>? _authSubscription;
  Session? _session;
  Object? _lastError;
  bool _initialized = false;

  Session? get session => _session;

  User? get user => _session?.user;

  bool get isAuthenticated => user != null;

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

    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
      (authState) {
        _session = authState.session;
        _lastError = null;
        notifyListeners();
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

  Future<void> signOut() async {
    if (!SupabaseService.isInitialized) {
      return;
    }

    await SupabaseService.client.auth.signOut();
    _session = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
