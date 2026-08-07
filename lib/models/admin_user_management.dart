import 'dart:convert';

class AdminManagedUser {
  const AdminManagedUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.businessCount,
    required this.providers,
    required this.isCurrentUser,
    this.avatarUrl,
    this.suspensionReason,
    this.suspendedAt,
    this.deletedAt,
    this.createdAt,
    this.lastSignInAt,
    this.emailConfirmedAt,
    this.bannedUntil,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final bool isActive;
  final int businessCount;
  final List<String> providers;
  final bool isCurrentUser;
  final String? avatarUrl;
  final String? suspensionReason;
  final DateTime? suspendedAt;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final DateTime? emailConfirmedAt;
  final DateTime? bannedUntil;

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isDeleted => deletedAt != null;
  bool get isSuspended => !isActive && !isDeleted;
  bool get isAuthBanned =>
      bannedUntil != null && bannedUntil!.isAfter(DateTime.now().toUtc());

  String get displayName {
    final name = fullName.trim();
    if (name.isNotEmpty) {
      return name;
    }
    final mail = email.trim();
    if (mail.isNotEmpty) {
      return mail.split('@').first;
    }
    return 'مستخدم دليل الحامي';
  }

  String get roleLabel => isAdmin ? 'مدير' : 'مستخدم';
  String get statusLabel {
    if (isDeleted) {
      return 'محذوف ظاهريًا';
    }
    return isActive ? 'نشط' : 'موقوف';
  }

  factory AdminManagedUser.fromMap(Map<String, dynamic> data) {
    return AdminManagedUser(
      id: data['id']?.toString() ?? '',
      fullName: data['full_name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      role: data['role']?.toString() ?? 'user',
      isActive: _readBoolean(data['is_active'], fallback: true),
      businessCount: _readInteger(data['business_count']),
      providers: _readStrings(data['providers']),
      isCurrentUser: _readBoolean(data['is_current_user']),
      avatarUrl: _nullableText(data['avatar_url']),
      suspensionReason: _nullableText(data['suspension_reason']),
      suspendedAt: _readDate(data['suspended_at']),
      deletedAt: _readDate(data['deleted_at']),
      createdAt: _readDate(data['created_at']),
      lastSignInAt: _readDate(data['last_sign_in_at']),
      emailConfirmedAt: _readDate(data['email_confirmed_at']),
      bannedUntil: _readDate(data['banned_until']),
    );
  }
}

class AdminUserPage {
  const AdminUserPage({
    required this.users,
    required this.page,
    required this.perPage,
    required this.total,
    required this.activeCount,
    required this.suspendedCount,
    required this.deletedCount,
    required this.adminCount,
  });

  final List<AdminManagedUser> users;
  final int page;
  final int perPage;
  final int total;
  final int activeCount;
  final int suspendedCount;
  final int deletedCount;
  final int adminCount;

  int get totalPages {
    if (total <= 0 || perPage <= 0) {
      return 1;
    }
    return (total / perPage).ceil();
  }

  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;

  factory AdminUserPage.fromResponse(Object? response) {
    final data = _readMap(response);
    return AdminUserPage(
      users: _readMapList(data['users'])
          .map(AdminManagedUser.fromMap)
          .where((user) => user.id.isNotEmpty)
          .toList(growable: false),
      page: _readInteger(data['page'], fallback: 1),
      perPage: _readInteger(data['per_page'], fallback: 20),
      total: _readInteger(data['total']),
      activeCount: _readInteger(data['active_count']),
      suspendedCount: _readInteger(data['suspended_count']),
      deletedCount: _readInteger(data['deleted_count']),
      adminCount: _readInteger(data['admin_count']),
    );
  }
}

class AdminUserBusinessSummary {
  const AdminUserBusinessSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String name;
  final String status;
  final bool isActive;
  final DateTime? createdAt;

  factory AdminUserBusinessSummary.fromMap(Map<String, dynamic> data) {
    return AdminUserBusinessSummary(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? 'نشاط غير مسمى',
      status: data['status']?.toString() ?? 'draft',
      isActive: _readBoolean(data['is_active'], fallback: true),
      createdAt: _readDate(data['created_at']),
    );
  }
}

class AdminUserAuditEntry {
  const AdminUserAuditEntry({
    required this.id,
    required this.action,
    required this.actorName,
    required this.reason,
    this.createdAt,
  });

  final String id;
  final String action;
  final String actorName;
  final String reason;
  final DateTime? createdAt;

  String get actionLabel => switch (action) {
        'suspended' => 'إيقاف الحساب',
        'activated' => 'تفعيل الحساب',
        'promoted' => 'منح صلاحية مدير',
        'demoted' => 'إلغاء صلاحية المدير',
        'soft_deleted' => 'حذف الحساب ظاهريًا',
        'restored' => 'استعادة الحساب',
        _ => action,
      };

  factory AdminUserAuditEntry.fromMap(Map<String, dynamic> data) {
    return AdminUserAuditEntry(
      id: data['id']?.toString() ?? '',
      action: data['action']?.toString() ?? '',
      actorName: data['actor_name']?.toString() ?? 'مدير النظام',
      reason: data['reason']?.toString() ?? '',
      createdAt: _readDate(data['created_at']),
    );
  }
}

class AdminManagedUserDetail {
  const AdminManagedUserDetail({
    required this.user,
    required this.businesses,
    required this.auditEntries,
  });

  final AdminManagedUser user;
  final List<AdminUserBusinessSummary> businesses;
  final List<AdminUserAuditEntry> auditEntries;

  factory AdminManagedUserDetail.fromResponse(Object? response) {
    final data = _readMap(response);
    return AdminManagedUserDetail(
      user: AdminManagedUser.fromMap(_readMap(data['user'])),
      businesses: _readMapList(data['businesses'])
          .map(AdminUserBusinessSummary.fromMap)
          .toList(growable: false),
      auditEntries: _readMapList(data['audit_entries'])
          .map(AdminUserAuditEntry.fromMap)
          .toList(growable: false),
    );
  }
}

class AdminUserActionResult {
  const AdminUserActionResult({
    required this.userId,
    required this.action,
    required this.message,
  });

  final String userId;
  final String action;
  final String message;

  factory AdminUserActionResult.fromResponse(Object? response) {
    final data = _readMap(response);
    return AdminUserActionResult(
      userId: data['user_id']?.toString() ?? '',
      action: data['action']?.toString() ?? '',
      message: data['message']?.toString() ?? 'تم تحديث المستخدم.',
    );
  }
}

Map<String, dynamic> _readMap(Object? value) {
  Object? decoded = value;
  if (decoded is String) {
    decoded = jsonDecode(decoded);
  }
  if (decoded is Map<String, dynamic>) {
    return Map<String, dynamic>.from(decoded);
  }
  if (decoded is Map) {
    return decoded.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('أعاد الخادم بيانات مستخدمين غير صالحة.');
}

List<Map<String, dynamic>> _readMapList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((item) => item.map((key, entry) => MapEntry(key.toString(), entry)))
      .toList(growable: false);
}

List<String> _readStrings(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

int _readInteger(Object? value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _readBoolean(Object? value, {bool fallback = false}) {
  if (value == null) {
    return fallback;
  }
  if (value is bool) {
    return value;
  }
  final text = value.toString().toLowerCase();
  return text == 'true' || text == '1';
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _readDate(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  return DateTime.tryParse(value?.toString() ?? '')?.toUtc();
}
