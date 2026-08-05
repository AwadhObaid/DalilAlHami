class AccountBusiness {
  const AccountBusiness({
    required this.id,
    required this.ownerId,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.phone,
    required this.whatsapp,
    required this.address,
    required this.status,
    required this.isActive,
    this.logoUrl,
    this.localLogoPath,
    this.rejectionReason,
    this.syncVersion = 0,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String categoryId;
  final String categoryName;
  final String name;
  final String description;
  final String phone;
  final String whatsapp;
  final String address;
  final String status;
  final bool isActive;
  final String? logoUrl;
  final String? localLogoPath;
  final String? rejectionReason;
  final int syncVersion;
  final DateTime? updatedAt;

  bool get isApproved => status == 'approved';

  bool get isWaitingForSync => status == 'local_pending';

  bool get hasSyncFailure => status == 'sync_failed';

  String get statusLabel {
    return switch (status) {
      'local_pending' => 'بانتظار المزامنة',
      'sync_failed' => 'تعذرت المزامنة',
      'draft' => 'مسودة',
      'pending' => 'قيد المراجعة',
      'approved' => 'معتمد',
      'rejected' => 'مرفوض',
      'changes_requested' => 'يحتاج تعديل',
      'suspended' => 'موقوف',
      _ => 'غير محدد',
    };
  }

  AccountBusiness copyWith({
    String? id,
    String? ownerId,
    String? categoryId,
    String? categoryName,
    String? name,
    String? description,
    String? phone,
    String? whatsapp,
    String? address,
    String? status,
    bool? isActive,
    String? logoUrl,
    String? localLogoPath,
    String? rejectionReason,
    int? syncVersion,
    DateTime? updatedAt,
  }) {
    return AccountBusiness(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      address: address ?? this.address,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      logoUrl: logoUrl ?? this.logoUrl,
      localLogoPath: localLogoPath ?? this.localLogoPath,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      syncVersion: syncVersion ?? this.syncVersion,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AccountBusiness.fromMap(Map<String, dynamic> data) {
    final categoryData = data['categories'];
    final category = categoryData is Map<String, dynamic>
        ? categoryData
        : categoryData is Map
            ? Map<String, dynamic>.from(categoryData)
            : const <String, dynamic>{};

    return AccountBusiness(
      id: data['id']?.toString() ?? '',
      ownerId: data['owner_id']?.toString() ?? '',
      categoryId: data['category_id']?.toString() ?? '',
      categoryName: category['name_ar']?.toString() ??
          data['category_name']?.toString() ??
          '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      whatsapp: data['whatsapp']?.toString() ?? '',
      address: data['address']?.toString() ?? 'الحامي',
      status: data['status']?.toString() ?? 'draft',
      isActive: data['is_active'] != false,
      logoUrl: _nullableText(data['logo_url']),
      localLogoPath: _nullableText(data['local_logo_path']),
      rejectionReason: _nullableText(data['rejection_reason']),
      syncVersion: _readInteger(data['sync_version']),
      updatedAt: DateTime.tryParse(
        data['updated_at']?.toString() ?? '',
      )?.toUtc(),
    );
  }

  static int _readInteger(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
