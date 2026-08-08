import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session_store.dart';
import 'supabase_service.dart';

class BusinessRatingSnapshot {
  const BusinessRatingSnapshot({
    required this.businessId,
    required this.averageRating,
    required this.ratingsCount,
    required this.userRating,
    required this.isLoading,
    required this.hasPendingRating,
    required this.lastError,
  });

  final String businessId;
  final double averageRating;
  final int ratingsCount;
  final int? userRating;
  final bool isLoading;
  final bool hasPendingRating;
  final Object? lastError;

  bool get hasRatings => ratingsCount > 0;
}

enum BusinessRatingSubmitResult {
  saved,
  queuedOffline,
  requiresSignIn,
  blockedAccount,
  invalidBusiness,
  invalidRating,
}

class BusinessRatingStore extends ChangeNotifier {
  BusinessRatingStore._();

  static final BusinessRatingStore instance = BusinessRatingStore._();

  static const String _summaryCacheKey = 'phase09.rating.summary.v1';
  static const String _userRatingsKey = 'phase09.rating.user.v1';
  static const String _pendingRatingsKey = 'phase09.rating.pending.v1';
  static const Duration _pendingRetryDelay = Duration(seconds: 6);

  final AuthSessionStore _authStore = AuthSessionStore.instance;

  SharedPreferences? _preferences;
  final Map<String, _RatingSummary> _summaries = <String, _RatingSummary>{};
  final Map<String, int> _userRatings = <String, int>{};
  final Map<String, int> _pendingRatings = <String, int>{};
  final Set<String> _loadingBusinessIds = <String>{};
  final Map<String, Object> _errors = <String, Object>{};

  Timer? _pendingRetryTimer;
  bool _syncPendingInProgress = false;
  bool _initialized = false;
  bool _listenerAttached = false;
  String? _lastObservedUserId;

  bool get isInitialized => _initialized;

  Future<void> initialize({bool reload = false}) async {
    if (_initialized && !reload) {
      return;
    }

    _preferences ??= await SharedPreferences.getInstance();
    _summaries
      ..clear()
      ..addAll(_readSummaryMap(_preferences?.getString(_summaryCacheKey)));
    _userRatings
      ..clear()
      ..addAll(_readIntegerMap(_preferences?.getString(_userRatingsKey)));
    _pendingRatings
      ..clear()
      ..addAll(_readIntegerMap(_preferences?.getString(_pendingRatingsKey)));

    if (!_listenerAttached) {
      _authStore.addListener(_handleAuthChanged);
      _listenerAttached = true;
    }

    _lastObservedUserId = _authStore.user?.id;
    _initialized = true;
    notifyListeners();

    if (_authStore.isAuthenticated && SupabaseService.isInitialized) {
      unawaited(syncPendingRatings());
    }
  }

  BusinessRatingSnapshot snapshotFor(String businessId) {
    final id = businessId.trim();
    final summary = _summaries[id] ?? const _RatingSummary();
    final accountKey = _accountBusinessKey(_authStore.user?.id, id);

    return BusinessRatingSnapshot(
      businessId: id,
      averageRating: summary.averageRating,
      ratingsCount: summary.ratingsCount,
      userRating: accountKey == null ? null : _userRatings[accountKey],
      isLoading: _loadingBusinessIds.contains(id),
      hasPendingRating:
          accountKey != null && _pendingRatings.containsKey(accountKey),
      lastError: _errors[id],
    );
  }

  Future<void> load(String businessId, {bool force = false}) async {
    await _ensureInitialized();
    final id = businessId.trim();
    if (!_isUuid(id) || !SupabaseService.isInitialized) {
      return;
    }
    if (_loadingBusinessIds.contains(id)) {
      return;
    }

    final user = _authStore.user;
    final accountKey = _accountBusinessKey(user?.id, id);
    final pendingRating = accountKey == null ? null : _pendingRatings[accountKey];
    if (user != null && pendingRating != null) {
      final synced = await _syncOne(
        userId: user.id,
        businessId: id,
        rating: pendingRating,
      );
      if (!synced) {
        return;
      }
    }

    if (!force && _summaries.containsKey(id) && _errors[id] == null) {
      // A cached value is useful for immediate rendering, but still refresh it
      // asynchronously so public averages do not remain stale indefinitely.
      unawaited(_loadRemote(id));
      return;
    }
    await _loadRemote(id);
  }

  Future<BusinessRatingSubmitResult> setRating(
    String businessId,
    int rating,
  ) async {
    await _ensureInitialized();
    final id = businessId.trim();
    if (!_isUuid(id)) {
      return BusinessRatingSubmitResult.invalidBusiness;
    }
    if (rating < 1 || rating > 5) {
      return BusinessRatingSubmitResult.invalidRating;
    }

    final user = _authStore.user;
    if (user == null) {
      return BusinessRatingSubmitResult.requiresSignIn;
    }
    if (_authStore.isAccountBlocked) {
      return BusinessRatingSubmitResult.blockedAccount;
    }

    final accountKey = _accountBusinessKey(user.id, id)!;
    final oldRating = _userRatings[accountKey];
    final oldSummary = _summaries[id] ?? const _RatingSummary();

    _userRatings[accountKey] = rating;
    _pendingRatings[accountKey] = rating;
    _summaries[id] = _optimisticSummary(
      oldSummary: oldSummary,
      oldRating: oldRating,
      newRating: rating,
    );
    _errors.remove(id);
    await _persist();
    notifyListeners();

    if (!SupabaseService.isInitialized) {
      return BusinessRatingSubmitResult.queuedOffline;
    }

    final synced = await _syncOne(
      userId: user.id,
      businessId: id,
      rating: rating,
    );
    return synced
        ? BusinessRatingSubmitResult.saved
        : BusinessRatingSubmitResult.queuedOffline;
  }

  Future<void> syncPendingRatings() async {
    await _ensureInitialized();
    final user = _authStore.user;
    if (user == null ||
        !SupabaseService.isInitialized ||
        _syncPendingInProgress) {
      return;
    }

    _syncPendingInProgress = true;
    final prefix = '${user.id}|';
    try {
      final pending = _pendingRatings.entries
          .where((entry) => entry.key.startsWith(prefix))
          .toList(growable: false);

      for (final entry in pending) {
        final businessId = entry.key.substring(prefix.length);
        if (!_isUuid(businessId)) {
          continue;
        }
        await _syncOne(
          userId: user.id,
          businessId: businessId,
          rating: entry.value,
        );
      }
    } finally {
      _syncPendingInProgress = false;
      if (_hasPendingForUser(user.id)) {
        _schedulePendingRetry();
      } else {
        _cancelPendingRetry();
      }
    }
  }

  Future<void> _loadRemote(String businessId) async {
    _loadingBusinessIds.add(businessId);
    _errors.remove(businessId);
    notifyListeners();

    try {
      final response = await SupabaseService.client.rpc(
        'get_business_rating_summary',
        params: <String, dynamic>{'p_business_id': businessId},
      );
      final row = _firstRow(response);
      if (row == null) {
        _summaries[businessId] = const _RatingSummary();
        await _persist();
        return;
      }

      _applyRemoteRow(businessId, row);
      await _persist();
    } catch (error, stackTrace) {
      _errors[businessId] = error;
      debugPrint('Business rating load failed: $error\n$stackTrace');
    } finally {
      _loadingBusinessIds.remove(businessId);
      notifyListeners();
    }
  }

  Future<bool> _syncOne({
    required String userId,
    required String businessId,
    required int rating,
  }) async {
    final accountKey = _accountBusinessKey(userId, businessId)!;
    _loadingBusinessIds.add(businessId);
    _errors.remove(businessId);
    notifyListeners();

    try {
      final response = await SupabaseService.client.rpc(
        'set_business_rating',
        params: <String, dynamic>{
          'p_business_id': businessId,
          'p_rating': rating,
        },
      );
      final row = _firstRow(response);
      if (row != null) {
        _applyRemoteRow(businessId, row, fallbackUserRating: rating);
      }
      _pendingRatings.remove(accountKey);
      await _persist();
      if (!_hasPendingForUser(userId)) {
        _cancelPendingRetry();
      }
      return true;
    } catch (error, stackTrace) {
      _errors[businessId] = error;
      debugPrint('Business rating sync failed: $error\n$stackTrace');
      await _persist();
      _schedulePendingRetry();
      return false;
    } finally {
      _loadingBusinessIds.remove(businessId);
      notifyListeners();
    }
  }

  void _applyRemoteRow(
    String businessId,
    Map<String, dynamic> row, {
    int? fallbackUserRating,
  }) {
    _summaries[businessId] = _RatingSummary(
      averageRating: _readDouble(row['average_rating']),
      ratingsCount: _readInt(row['ratings_count']),
    );

    final userId = _authStore.user?.id;
    final accountKey = _accountBusinessKey(userId, businessId);
    if (accountKey == null) {
      return;
    }

    final pendingUserRating = _pendingRatings[accountKey];
    if (pendingUserRating != null) {
      _userRatings[accountKey] = pendingUserRating;
      return;
    }

    final remoteUserRating = _nullableRating(row['user_rating']);
    if (remoteUserRating != null) {
      _userRatings[accountKey] = remoteUserRating;
    } else if (fallbackUserRating != null) {
      _userRatings[accountKey] = fallbackUserRating;
    } else if (!_pendingRatings.containsKey(accountKey)) {
      _userRatings.remove(accountKey);
    }
  }

  _RatingSummary _optimisticSummary({
    required _RatingSummary oldSummary,
    required int? oldRating,
    required int newRating,
  }) {
    final oldCount = oldSummary.ratingsCount;
    final oldTotal = oldSummary.averageRating * oldCount;
    if (oldRating == null) {
      final newCount = oldCount + 1;
      return _RatingSummary(
        averageRating: newCount == 0 ? 0 : (oldTotal + newRating) / newCount,
        ratingsCount: newCount,
      );
    }

    if (oldCount <= 0) {
      return _RatingSummary(
        averageRating: newRating.toDouble(),
        ratingsCount: 1,
      );
    }

    return _RatingSummary(
      averageRating: (oldTotal - oldRating + newRating) / oldCount,
      ratingsCount: oldCount,
    );
  }

  void _handleAuthChanged() {
    final userId = _authStore.user?.id;
    if (userId == _lastObservedUserId) {
      return;
    }
    _lastObservedUserId = userId;
    _cancelPendingRetry();
    notifyListeners();
    if (userId != null && SupabaseService.isInitialized) {
      unawaited(syncPendingRatings());
    }
  }

  bool _hasPendingForUser(String userId) {
    final prefix = '$userId|';
    return _pendingRatings.keys.any((key) => key.startsWith(prefix));
  }

  void _schedulePendingRetry() {
    final user = _authStore.user;
    if (user == null ||
        !SupabaseService.isInitialized ||
        !_hasPendingForUser(user.id)) {
      return;
    }

    _pendingRetryTimer?.cancel();
    _pendingRetryTimer = Timer(_pendingRetryDelay, () {
      _pendingRetryTimer = null;
      unawaited(syncPendingRatings());
    });
  }

  void _cancelPendingRetry() {
    _pendingRetryTimer?.cancel();
    _pendingRetryTimer = null;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Map<String, _RatingSummary> _readSummaryMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, _RatingSummary>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, _RatingSummary>{};
      }
      final result = <String, _RatingSummary>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is Map) {
          result[key] = _RatingSummary(
            averageRating: _readDouble(value['average']),
            ratingsCount: _readInt(value['count']),
          );
        }
      }
      return result;
    } catch (_) {
      return <String, _RatingSummary>{};
    }
  }

  Map<String, int> _readIntegerMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, int>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, int>{};
      }
      return <String, int>{
        for (final entry in decoded.entries)
          if (_readInt(entry.value) case final value when value > 0)
            entry.key.toString(): value,
      };
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> _persist() async {
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }

    final summaryJson = <String, dynamic>{
      for (final entry in _summaries.entries)
        entry.key: <String, dynamic>{
          'average': entry.value.averageRating,
          'count': entry.value.ratingsCount,
        },
    };

    await preferences.setString(_summaryCacheKey, jsonEncode(summaryJson));
    await preferences.setString(_userRatingsKey, jsonEncode(_userRatings));
    await preferences.setString(_pendingRatingsKey, jsonEncode(_pendingRatings));
  }

  Map<String, dynamic>? _firstRow(dynamic response) {
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }
    if (response is Map<String, dynamic>) {
      return response;
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return null;
  }

  String? _accountBusinessKey(String? userId, String businessId) {
    final id = userId?.trim() ?? '';
    if (id.isEmpty || businessId.isEmpty) {
      return null;
    }
    return '$id|$businessId';
  }

  int? _nullableRating(dynamic value) {
    if (value == null) {
      return null;
    }
    final rating = _readInt(value);
    return rating >= 1 && rating <= 5 ? rating : null;
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _readDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
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
    _summaries.clear();
    _userRatings.clear();
    _pendingRatings.clear();
    _loadingBusinessIds.clear();
    _errors.clear();
    _cancelPendingRetry();
    _syncPendingInProgress = false;
    _initialized = true;
    await _persist();
    notifyListeners();
  }
}

class _RatingSummary {
  const _RatingSummary({
    this.averageRating = 0,
    this.ratingsCount = 0,
  });

  final double averageRating;
  final int ratingsCount;
}
