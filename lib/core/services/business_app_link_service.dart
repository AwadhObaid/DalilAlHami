import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../data/directory_data_store.dart';
import '../../features/directory/member_details_page.dart';
import '../../models/business.dart';
import '../navigation/app_navigator.dart';
import 'business_share_link.dart';
import 'supabase_service.dart';

class BusinessAppLinkService {
  BusinessAppLinkService._();

  static final BusinessAppLinkService instance = BusinessAppLinkService._();

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _subscription;
  String? _pendingBusinessId;
  bool _initialized = false;
  bool _shellReady = false;
  bool _opening = false;

  void initialize() {
    if (_initialized) {
      return;
    }
    _initialized = true;

    _subscription = _appLinks.uriLinkStream.listen(
      handleUri,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Business app-link stream failed: $error\n$stackTrace');
      },
    );
  }

  void handleUri(Uri uri) {
    final businessId = BusinessShareLink.businessIdFromUri(uri);
    if (businessId == null) {
      return;
    }
    unawaited(openOrQueue(businessId));
  }

  void markShellReady() {
    _shellReady = true;
    final pending = _pendingBusinessId;
    _pendingBusinessId = null;
    if (pending != null) {
      unawaited(openOrQueue(pending));
    }
  }

  Future<void> openOrQueue(String businessId) async {
    final safeId = businessId.trim();
    final navigator = appNavigatorKey.currentState;
    if (safeId.isEmpty || !_shellReady || navigator == null || _opening) {
      if (safeId.isNotEmpty) {
        _pendingBusinessId = safeId;
      }
      return;
    }

    _opening = true;
    try {
      final business = await _resolveBusiness(safeId);
      if (business == null) {
        _showUnavailableMessage(navigator);
        return;
      }

      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MemberDetailsPage(business: business),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Business app-link navigation failed: $error\n$stackTrace');
      _showUnavailableMessage(navigator);
    } finally {
      _opening = false;
      final queued = _pendingBusinessId;
      _pendingBusinessId = null;
      if (queued != null && queued != safeId) {
        unawaited(openOrQueue(queued));
      }
    }
  }

  Future<Business?> _resolveBusiness(String businessId) async {
    final store = DirectoryDataStore.instance;
    await store.load();

    var business = _findBusiness(store, businessId);
    if (business != null || !SupabaseService.isInitialized) {
      return business;
    }

    try {
      await store.refresh();
    } catch (_) {
      // The local directory remains usable when the network refresh fails.
    }
    business = _findBusiness(store, businessId);
    return business;
  }

  Business? _findBusiness(DirectoryDataStore store, String businessId) {
    for (final candidate in store.businesses) {
      if (candidate.id == businessId && !candidate.isDeleted) {
        return candidate;
      }
    }
    return null;
  }

  void _showUnavailableMessage(NavigatorState navigator) {
    if (!navigator.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(navigator.context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر العثور على النشاط المشارك. حدّث الدليل ثم أعد المحاولة.',
          ),
        ),
      );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
