import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/business.dart';
import 'auth_session_store.dart';
import 'supabase_service.dart';

class FavoriteStore extends ChangeNotifier {
  FavoriteStore._();

  static final FavoriteStore instance = FavoriteStore._();

  static const String _favoriteIdsKey = 'phase09.favorite_ids.v1';
  static const String _pendingAddsKey = 'phase09.favorite_pending_adds.v1';
  static const String _pendingRemovesKey = 'phase09.favorite_pending_removes.v1';

  final AuthSessionStore _authStore = AuthSessionStore.instance;

  SharedPreferences? _preferences;
  Set<String> _favoriteIds = <String>{};
  Set<String> _pendingAdds = <String>{};
  Set<String> _pendingRemoves = <String>{};

  bool _initialized = false;
  bool _listenerAttached = false;
  bool _isSyncing = false;
  Object? _lastError;
  String? _lastObservedUserId;

  bool get isInitialized => _initialized;

  bool get isSyncing => _isSyncing;

  Object? get lastError => _lastError;

  Set<String> get favoriteIds => Set<String>.unmodifiable(_favoriteIds);

  int get count => _favoriteIds.length;

  bool isFavorite(String businessId) {
    final id = businessId.trim();
    return id.isNotEmpty && _favoriteIds.contains(id);
  }

  List<Business> favoriteBusinesses(Iterable<Business> businesses) {
    return businesses
        .where((business) => _favoriteIds.contains(business.id))
        .toList(growable: false);
  }

  Future<void> initialize({bool reload = false}) async {
    if (_initialized && !reload) {
      return;
    }

    _preferences ??= await SharedPreferences.getInstance();

    _favoriteIds = _readSet(_favoriteIdsKey);
    _pendingAdds = _readSet(_pendingAddsKey);
    _pendingRemoves = _readSet(_pendingRemovesKey);

    if (!_listenerAttached) {
      _authStore.addListener(_handleAuthChanged);
      _listenerAttached = true;
    }

    _lastObservedUserId = _authStore.user?.id;
    _initialized = true;
    _lastError = null;
    notifyListeners();

    if (_authStore.isAuthenticated && SupabaseService.isInitialized) {
      unawaited(syncWithRemote());
    }
  }

  Future<bool> toggleFavorite(String businessId) async {
    await _ensureInitialized();

    final id = businessId.trim();
    if (id.isEmpty) {
      return false;
    }

    final shouldFavorite = !_favoriteIds.contains(id);
    if (shouldFavorite) {
      _favoriteIds.add(id);
      if (_isUuid(id)) {
        _pendingRemoves.remove(id);
        _pendingAdds.add(id);
      }
    } else {
      _favoriteIds.remove(id);
      if (_isUuid(id)) {
        _pendingAdds.remove(id);
        _pendingRemoves.add(id);
      }
    }

    await _persist();
    notifyListeners();

    if (_authStore.isAuthenticated &&
        SupabaseService.isInitialized &&
        _isUuid(id)) {
      unawaited(syncWithRemote());
    }

    return shouldFavorite;
  }

  Future<void> syncWithRemote() async {
    await _ensureInitialized();

    final user = _authStore.user;
    if (_isSyncing || user == null || !SupabaseService.isInitialized) {
      return;
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final pendingRemoves = _pendingRemoves.where(_isUuid).toList();
      for (final businessId in pendingRemoves) {
        await SupabaseService.client
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('business_id', businessId);
        _pendingRemoves.remove(businessId);
      }

      final pendingAdds = _pendingAdds.where(_isUuid).toList();
      for (final businessId in pendingAdds) {
        await SupabaseService.client.from('favorites').upsert(
          <String, dynamic>{
            'user_id': user.id,
            'business_id': businessId,
          },
          onConflict: 'user_id,business_id',
        );
        _pendingAdds.remove(businessId);
      }

      final rows = await SupabaseService.client
          .from('favorites')
          .select('business_id')
          .eq('user_id', user.id);

      final remoteIds = <String>{
        for (final row in rows)
          if (row['business_id']?.toString().trim() case final id?
              when id.isNotEmpty)
            id,
      };

      final localOnlyIds =
          _favoriteIds.where((id) => !_isUuid(id)).toSet();

      // The server is authoritative for UUID-backed businesses after pending
      // local mutations have been flushed. Bundled/non-UUID items remain local.
      _favoriteIds = <String>{
        ...localOnlyIds,
        ...remoteIds,
        ..._pendingAdds.where(_isUuid),
      }..removeAll(_pendingRemoves.where(_isUuid));

      await _persist();
    } catch (error, stackTrace) {
      _lastError = error;
      debugPrint('Favorite synchronization failed: $error\n$stackTrace');
      await _persist();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _handleAuthChanged() {
    final userId = _authStore.user?.id;
    if (userId == _lastObservedUserId) {
      return;
    }

    _lastObservedUserId = userId;
    notifyListeners();

    if (userId != null && SupabaseService.isInitialized) {
      unawaited(syncWithRemote());
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Set<String> _readSet(String key) {
    return (_preferences?.getStringList(key) ?? const <String>[])
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  Future<void> _persist() async {
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }

    final favorites = _favoriteIds.toList()..sort();
    final pendingAdds = _pendingAdds.toList()..sort();
    final pendingRemoves = _pendingRemoves.toList()..sort();

    await preferences.setStringList(_favoriteIdsKey, favorites);
    await preferences.setStringList(_pendingAddsKey, pendingAdds);
    await preferences.setStringList(_pendingRemovesKey, pendingRemoves);
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
      r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _preferences ??= await SharedPreferences.getInstance();
    _favoriteIds = <String>{};
    _pendingAdds = <String>{};
    _pendingRemoves = <String>{};
    _lastError = null;
    _isSyncing = false;
    _initialized = true;
    await _persist();
    notifyListeners();
  }
}
