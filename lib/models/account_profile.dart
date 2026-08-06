class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.isActive,
    this.email,
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String phone;
  final String role;
  final bool isActive;
  final String? email;
  final String? avatarUrl;

  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  AccountProfile copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? role,
    bool? isActive,
    String? email,
    String? avatarUrl,
    bool clearAvatarUrl = false,
  }) {
    return AccountProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      email: email ?? this.email,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
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
    );
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
