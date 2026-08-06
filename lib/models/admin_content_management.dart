import 'business_gallery_image.dart';

class AdminCategoryItem {
  const AdminCategoryItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconName,
    required this.sortOrder,
    required this.displayGroup,
    required this.isActive,
    required this.businessCount,
    required this.activeBusinessCount,
    required this.updatedAt,
    this.imageUrl,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String iconName;
  final int sortOrder;
  final String displayGroup;
  final bool isActive;
  final int businessCount;
  final int activeBusinessCount;
  final DateTime updatedAt;
  final String? imageUrl;
  final DateTime? deletedAt;

  bool get isArchived => !isActive || deletedAt != null;
  bool get canDeletePermanently => businessCount == 0;
  String get groupLabel => displayGroup == 'transport' ? 'النقل' : 'الخدمات';

  factory AdminCategoryItem.fromMap(
    Map<String, dynamic> data, {
    int businessCount = 0,
    int activeBusinessCount = 0,
  }) {
    return AdminCategoryItem(
      id: data['id']?.toString() ?? '',
      name: data['name_ar']?.toString() ?? '',
      slug: data['slug']?.toString() ?? '',
      iconName: data['icon_name']?.toString() ?? 'category',
      sortOrder: _readInteger(data['sort_order']),
      displayGroup: data['display_group']?.toString() == 'transport'
          ? 'transport'
          : 'services',
      isActive: _readBoolean(data['is_active']),
      businessCount: businessCount,
      activeBusinessCount: activeBusinessCount,
      updatedAt: _readDate(data['updated_at']),
      imageUrl: _nullableText(data['image_url']),
      deletedAt: _readNullableDate(data['deleted_at']),
    );
  }
}

class AdminCategoryDraft {
  const AdminCategoryDraft({
    required this.name,
    required this.slug,
    required this.iconName,
    required this.sortOrder,
    required this.displayGroup,
    this.id,
    this.imageUrl,
  });

  final String? id;
  final String name;
  final String slug;
  final String iconName;
  final int sortOrder;
  final String displayGroup;
  final String? imageUrl;

  bool get isEditing => id != null && id!.trim().isNotEmpty;
}

class AdminBusinessItem {
  const AdminBusinessItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.phone,
    required this.whatsapp,
    required this.address,
    required this.status,
    required this.isFeatured,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.ownerId,
    this.ownerName,
    this.ownerEmail,
    this.latitude,
    this.longitude,
    this.logoUrl,
    this.coverUrl,
    this.galleryImages = const <BusinessGalleryImage>[],
    this.rejectionReason,
    this.deletedAt,
  });

  final String id;
  final String categoryId;
  final String categoryName;
  final String name;
  final String description;
  final String phone;
  final String whatsapp;
  final String address;
  final String status;
  final bool isFeatured;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ownerId;
  final String? ownerName;
  final String? ownerEmail;
  final double? latitude;
  final double? longitude;
  final String? logoUrl;
  final String? coverUrl;
  final List<BusinessGalleryImage> galleryImages;
  final String? rejectionReason;
  final DateTime? deletedAt;

  bool get isSuspended => status == 'suspended';
  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isDeleted => deletedAt != null;
  bool get canBeFeatured => isApproved && isActive && !isDeleted;

  String get displayOwner {
    final name = ownerName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final email = ownerEmail?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }
    return ownerId == null || ownerId!.isEmpty
        ? 'نشاط تديره الإدارة'
        : 'مالك غير مسمى';
  }

  String get statusLabel => adminBusinessStatusLabel(status);

  factory AdminBusinessItem.fromMap(
    Map<String, dynamic> data, {
    String? ownerName,
    String? ownerEmail,
  }) {
    final categoryData = data['categories'];
    final category = categoryData is Map<String, dynamic>
        ? categoryData
        : categoryData is Map
            ? Map<String, dynamic>.from(categoryData)
            : const <String, dynamic>{};

    return AdminBusinessItem(
      id: data['id']?.toString() ?? '',
      ownerId: _nullableText(data['owner_id']),
      ownerName: _nullableText(ownerName),
      ownerEmail: _nullableText(ownerEmail),
      categoryId: data['category_id']?.toString() ?? '',
      categoryName: category['name_ar']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      whatsapp: data['whatsapp']?.toString() ?? '',
      address: data['address']?.toString() ?? 'الحامي',
      latitude: _readDouble(data['latitude']),
      longitude: _readDouble(data['longitude']),
      logoUrl: _nullableText(data['logo_url']),
      coverUrl: _nullableText(data['cover_url']),
      galleryImages: BusinessGalleryImage.readList(data['business_images']),
      status: data['status']?.toString() ?? 'draft',
      rejectionReason: _nullableText(data['rejection_reason']),
      isFeatured: _readBoolean(data['is_featured']),
      isActive: _readBoolean(data['is_active']),
      createdAt: _readDate(data['created_at']),
      updatedAt: _readDate(data['updated_at']),
      deletedAt: _readNullableDate(data['deleted_at']),
    );
  }
}

class AdminBusinessDraft {
  const AdminBusinessDraft({
    required this.categoryId,
    required this.name,
    required this.description,
    required this.phone,
    required this.whatsapp,
    required this.address,
    this.id,
    this.latitude,
    this.longitude,
    this.logoUrl,
    this.coverUrl,
  });

  final String? id;
  final String categoryId;
  final String name;
  final String description;
  final String phone;
  final String whatsapp;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? logoUrl;
  final String? coverUrl;

  bool get isEditing => id != null && id!.trim().isNotEmpty;
}

enum AdminBusinessManagementAction {
  feature,
  unfeature,
  suspend,
  restore;

  String get rpcValue => switch (this) {
        AdminBusinessManagementAction.feature => 'feature',
        AdminBusinessManagementAction.unfeature => 'unfeature',
        AdminBusinessManagementAction.suspend => 'suspend',
        AdminBusinessManagementAction.restore => 'restore',
      };

  bool get requiresReason => this == AdminBusinessManagementAction.suspend;
}

class AdminContentMutationResult {
  const AdminContentMutationResult({
    required this.entityId,
    required this.entityType,
    required this.action,
    required this.message,
  });

  final String entityId;
  final String entityType;
  final String action;
  final String message;

  factory AdminContentMutationResult.fromRpc(Object? response) {
    final data = _asMap(response);
    return AdminContentMutationResult(
      entityId: data['entity_id']?.toString() ?? '',
      entityType: data['entity_type']?.toString() ?? '',
      action: data['action']?.toString() ?? '',
      message: data['message']?.toString() ?? 'تم حفظ التغييرات.',
    );
  }
}

String adminBusinessStatusLabel(String status) {
  return switch (status) {
    'approved' => 'معتمد',
    'pending' => 'قيد المراجعة',
    'rejected' => 'مرفوض',
    'changes_requested' => 'يحتاج تعديل',
    'suspended' => 'موقوف',
    _ => 'مسودة',
  };
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  if (value is List && value.isNotEmpty && value.first is Map) {
    final first = value.first as Map;
    return first.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Supabase returned an invalid admin result.');
}

bool _readBoolean(Object? value) {
  return value == true || value == 1 || value?.toString() == '1';
}

int _readInteger(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

DateTime _readDate(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '')?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? _readNullableDate(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text)?.toUtc();
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
