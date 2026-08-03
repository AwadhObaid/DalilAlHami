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
    this.rejectionReason,
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
  final String? rejectionReason;

  bool get isApproved => status == 'approved';

  String get statusLabel {
    return switch (status) {
      'draft' => 'مسودة',
      'pending' => 'قيد المراجعة',
      'approved' => 'معتمد',
      'rejected' => 'مرفوض',
      'suspended' => 'موقوف',
      _ => 'غير محدد',
    };
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
      categoryName: category['name_ar']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      whatsapp: data['whatsapp']?.toString() ?? '',
      address: data['address']?.toString() ?? 'الحامي',
      status: data['status']?.toString() ?? 'draft',
      isActive: data['is_active'] != false,
      logoUrl: _nullableText(data['logo_url']),
      rejectionReason: _nullableText(data['rejection_reason']),
    );
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
