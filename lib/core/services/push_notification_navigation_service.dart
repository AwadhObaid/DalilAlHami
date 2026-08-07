import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/directory_data_store.dart';
import '../../models/business.dart';
import '../../features/directory/member_details_page.dart';
import '../../features/home/home_screen.dart';
import '../navigation/app_navigator.dart';
import 'push_notification_intent.dart';

class PushNotificationNavigationService {
  PushNotificationNavigationService._();

  static final PushNotificationNavigationService instance =
      PushNotificationNavigationService._();

  PushNotificationIntent? _pendingIntent;
  bool _shellReady = false;
  bool _navigating = false;

  void handleData(Map<String, dynamic> data) {
    final intent = PushNotificationIntent.fromData(data);
    if (intent != null) {
      unawaited(openOrQueue(intent));
    }
  }

  void handleLocalPayload(String? payload) {
    final intent = PushNotificationIntent.fromPayload(payload);
    if (intent != null) {
      unawaited(openOrQueue(intent));
    }
  }

  void markShellReady() {
    _shellReady = true;
    final intent = _pendingIntent;
    _pendingIntent = null;
    if (intent != null) {
      unawaited(openOrQueue(intent));
    }
  }

  Future<void> openOrQueue(PushNotificationIntent intent) async {
    final navigator = appNavigatorKey.currentState;
    if (!_shellReady || navigator == null || _navigating) {
      _pendingIntent = intent;
      return;
    }

    _navigating = true;
    try {
      switch (intent.target) {
        case PushNotificationTarget.home:
          await _openHomeTab(navigator, 0);
          break;
        case PushNotificationTarget.categories:
          await _openHomeTab(navigator, 1);
          break;
        case PushNotificationTarget.search:
          await _openHomeTab(navigator, 2);
          break;
        case PushNotificationTarget.account:
          await _openHomeTab(navigator, 3);
          break;
        case PushNotificationTarget.business:
          await _openBusiness(navigator, intent.businessId);
          break;
      }
    } finally {
      _navigating = false;
      final queued = _pendingIntent;
      _pendingIntent = null;
      if (queued != null) {
        unawaited(openOrQueue(queued));
      }
    }
  }

  Future<void> _openHomeTab(NavigatorState navigator, int index) async {
    unawaited(navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(initialIndex: index),
      ),
      (_) => false,
    ));
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _openBusiness(
    NavigatorState navigator,
    String? businessId,
  ) async {
    final id = businessId?.trim();
    if (id == null || id.isEmpty) {
      return;
    }

    final store = DirectoryDataStore.instance;
    await store.load();

    Business? business;
    for (final candidate in store.businesses) {
      if (candidate.id == id) {
        business = candidate;
        break;
      }
    }

    final selectedBusiness = business;
    if (selectedBusiness == null) {
      return;
    }

    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MemberDetailsPage(business: selectedBusiness),
        ),
      ),
    );
  }
}
