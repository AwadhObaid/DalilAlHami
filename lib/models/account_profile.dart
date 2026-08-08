class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.isActive,
    this.email,
    this.avatarUrl,
    this.deletedAt,
    this.suspensionReason,
  });

  final String id;
  final String fullName;
  final String phone;
  final String role;
  final bool isActive;
  final String? email;
  final String? avatarUrl;
  final DateTime? deletedAt;
  final String? suspensionReason;

  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  bool get isDeleted => deletedAt != null;

  bool get canUseAccount => isActive && !isDeleted;

  AccountProfile copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? role,
    bool? isActive,
    String? email,
    String? avatarUrl,
    DateTime? deletedAt,
    String? suspensionReason,
    bool clearAvatarUrl = false,
    bool clearDeletedAt = false,
    bool clearSuspensionReason = false,
  }) {
    return AccountProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      email: email ?? this.email,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
      suspensionReason: clearSuspensionReason
          ? null
          : suspensionReason ?? this.suspensionReason,
    );
  }

  factory AccountProfile.fromMap(Map<String, dynamic> data) {
    return AccountProfile(
      id: data['id']?.toString() ?? '',
      fullName: data['full_name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      role: data['role']?.toString() ?? 'user',
      isActive: data['is_active'] != false,
      email: _nullableText(data['email']),
      avatarUrl: _nullableText(data['avatar_url']),
      deletedAt: _readDate(data['deleted_at']),
      suspensionReason: _nullableText(data['suspension_reason']),
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is DateTime) {
      return value.toUtc();
    }
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return DateTime.tryParse(text)?.toUtc();
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
