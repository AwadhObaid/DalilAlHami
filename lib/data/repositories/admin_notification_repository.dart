import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../models/account_profile.dart';
import '../../models/admin_notification_management.dart';
import 'admin_repository.dart';

class AdminNotificationRepository {
  AdminNotificationRepository({AdminRepository? adminRepository})
      : _adminRepository = adminRepository ?? AdminRepository();

  final AdminRepository _adminRepository;

  SupabaseClient get _client => SupabaseService.client;

  Future<AccountProfile> loadCurrentAdminProfile() {
    return _adminRepository.loadCurrentAdminProfile();
  }

  Future<List<AdminNotificationUserOption>> loadUserOptions({
    String query = '',
  }) async {
    final response = await _invoke(<String, dynamic>{
      'action': 'user_options',
      'query': query.trim(),
    });
    final map = _asMap(response);
    final values = map['users'];
    if (values is! List) {
      return const <AdminNotificationUserOption>[];
    }
    return values
        .whereType<Map>()
        .map(
          (row) => AdminNotificationUserOption.fromMap(
            row.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<AdminNotificationHistoryItem>> loadHistory() async {
    final response = await _invoke(<String, dynamic>{
      'action': 'history',
      'limit': 30,
    });
    final map = _asMap(response);
    final values = map['notifications'];
    if (values is! List) {
      return const <AdminNotificationHistoryItem>[];
    }
    return values
        .whereType<Map>()
        .map(
          (row) => AdminNotificationHistoryItem.fromMap(
            row.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<AdminNotificationSendResult> send({
    required String title,
    required String body,
    required AdminNotificationAudience audience,
    required AdminNotificationNavigation navigation,
    String? targetUserId,
    String? businessId,
  }) async {
    final response = await _invoke(<String, dynamic>{
      'action': 'send',
      'title': title.trim(),
      'body': body.trim(),
      'target_type': audience.rpcValue,
      'target_user_id':
          audience == AdminNotificationAudience.user ? targetUserId : null,
      'navigation_type': navigation.rpcValue,
      'business_id': navigation == AdminNotificationNavigation.business
          ? businessId
          : null,
    });
    return AdminNotificationSendResult.fromMap(_asMap(response));
  }

  Future<Object?> _invoke(Map<String, dynamic> body) async {
    if (!SupabaseService.isInitialized) {
      throw const AdminNotificationRepositoryFailure(
        'تحتاج إدارة الإشعارات إلى اتصال Supabase صالح.',
      );
    }

    final session = _client.auth.currentSession;
    if (session == null) {
      throw const AdminAccessDenied('يجب تسجيل الدخول أولًا.');
    }

    try {
      final response = await _client.functions.invoke(
        'admin-notifications',
        body: body,
        headers: <String, String>{
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );
      if (response.status < 200 || response.status >= 300) {
        throw AdminNotificationRepositoryFailure(
          _messageFromDetails(response.data),
        );
      }
      return response.data;
    } on FunctionException catch (error) {
      final message = _messageFromDetails(error.details);
      if (error.status == 401 || error.status == 403) {
        throw AdminAccessDenied(message);
      }
      throw AdminNotificationRepositoryFailure(message);
    } on AdminAccessDenied {
      rethrow;
    } on AdminNotificationRepositoryFailure {
      rethrow;
    } catch (_) {
      throw const AdminNotificationRepositoryFailure(
        'تعذر الاتصال بخدمة إرسال الإشعارات. تحقق من الإنترنت ثم أعد المحاولة.',
      );
    }
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  String _messageFromDetails(Object? details) {
    Object? normalized = details;
    if (details is String) {
      try {
        normalized = jsonDecode(details);
      } on FormatException {
        normalized = details;
      }
    }
    if (normalized is Map) {
      final value = normalized['message'] ?? normalized['error'];
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    final text = normalized?.toString().trim();
    if (text != null && text.isNotEmpty && text != '{}') {
      return text;
    }
    return 'تعذر تنفيذ عملية الإشعارات.';
  }
}

class AdminNotificationRepositoryFailure implements Exception {
  const AdminNotificationRepositoryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
