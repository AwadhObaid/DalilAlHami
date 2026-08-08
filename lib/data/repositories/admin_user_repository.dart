import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../models/account_profile.dart';
import '../../models/admin_user_management.dart';
import 'admin_repository.dart';

class AdminUserRepository {
  AdminUserRepository({AdminRepository? adminRepository})
      : _adminRepository = adminRepository ?? AdminRepository();

  final AdminRepository _adminRepository;

  SupabaseClient get _client => SupabaseService.client;

  Future<AccountProfile> loadCurrentAdminProfile() {
    return _adminRepository.loadCurrentAdminProfile();
  }

  Future<AdminUserPage> loadUsers({
    String query = '',
    String status = 'all',
    String role = 'all',
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _invoke(<String, dynamic>{
      'action': 'list',
      'query': query.trim(),
      'status': status,
      'role': role,
      'page': page,
      'per_page': perPage,
    });
    return AdminUserPage.fromResponse(response);
  }

  Future<AdminManagedUserDetail> loadUserDetail(String userId) async {
    final response = await _invoke(<String, dynamic>{
      'action': 'detail',
      'user_id': userId,
    });
    return AdminManagedUserDetail.fromResponse(response);
  }

  Future<AdminUserActionResult> setUserActive({
    required String userId,
    required bool isActive,
    String? reason,
  }) async {
    final response = await _invoke(<String, dynamic>{
      'action': 'set_status',
      'user_id': userId,
      'is_active': isActive,
      'reason': reason?.trim(),
    });
    final result = AdminUserActionResult.fromResponse(response);
    if (result.profileIsActive != isActive || result.profileIsDeleted == true) {
      throw const AdminUserRepositoryFailure(
        'أعاد الخادم نجاح العملية لكن حالة الحساب لم تتطابق مع الطلب.',
      );
    }
    return result;
  }

  Future<AdminUserActionResult> setUserDeleted({
    required String userId,
    required bool isDeleted,
    String? reason,
  }) async {
    final response = await _invoke(<String, dynamic>{
      'action': 'set_deleted',
      'user_id': userId,
      'is_deleted': isDeleted,
      'reason': reason?.trim(),
    });
    final result = AdminUserActionResult.fromResponse(response);
    if (result.profileIsDeleted != isDeleted ||
        (isDeleted && result.profileIsActive != false) ||
        (!isDeleted && result.profileIsActive != true)) {
      throw const AdminUserRepositoryFailure(
        'أعاد الخادم نجاح العملية لكن حالة الحذف الظاهري لم تتطابق مع الطلب.',
      );
    }
    return result;
  }

  Future<AdminUserActionResult> setUserRole({
    required String userId,
    required String role,
  }) async {
    final response = await _invoke(<String, dynamic>{
      'action': 'set_role',
      'user_id': userId,
      'role': role,
    });
    final result = AdminUserActionResult.fromResponse(response);
    if (result.profileRole?.trim().toLowerCase() != role.trim().toLowerCase()) {
      throw const AdminUserRepositoryFailure(
        'أعاد الخادم نجاح العملية لكن صلاحية المستخدم لم تتطابق مع الطلب.',
      );
    }
    return result;
  }

  Future<Object?> _invoke(Map<String, dynamic> body) async {
    if (!SupabaseService.isInitialized) {
      throw const AdminUserRepositoryFailure(
        'تحتاج إدارة المستخدمين إلى اتصال Supabase صالح.',
      );
    }

    final session = _client.auth.currentSession;
    if (session == null) {
      throw const AdminAccessDenied('يجب تسجيل الدخول أولًا.');
    }

    try {
      final response = await _client.functions.invoke(
        'admin-users',
        body: body,
        headers: <String, String>{
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );
      if (response.status < 200 || response.status >= 300) {
        throw AdminUserRepositoryFailure(
          _messageFromDetails(response.data),
        );
      }
      return response.data;
    } on FunctionException catch (error) {
      final message = _messageFromDetails(error.details);
      if (error.status == 401 || error.status == 403) {
        throw AdminAccessDenied(message);
      }
      throw AdminUserRepositoryFailure(message);
    } on AdminAccessDenied {
      rethrow;
    } on AdminUserRepositoryFailure {
      rethrow;
    } catch (_) {
      throw const AdminUserRepositoryFailure(
        'تعذر الاتصال بخدمة إدارة المستخدمين. تحقق من الإنترنت ثم أعد المحاولة.',
      );
    }
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
    return 'تعذر تنفيذ عملية إدارة المستخدم.';
  }
}

class AdminUserRepositoryFailure implements Exception {
  const AdminUserRepositoryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
