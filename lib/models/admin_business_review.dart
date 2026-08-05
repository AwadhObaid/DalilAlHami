class AdminBusinessImage {
  const AdminBusinessImage({
    required this.id,
    required this.storagePath,
    required this.publicUrl,
    required this.altText,
    required this.sortOrder,
  });

  final String id;
  final String storagePath;
  final String publicUrl;
  final String altText;
  final int sortOrder;

  factory AdminBusinessImage.fromMap(
    Map<String, dynamic> data, {
    required String Function(String storagePath) publicUrlBuilder,
  }) {
    final storagePath = data['storage_path']?.toString().trim() ?? '';
    return AdminBusinessImage(
      id: data['id']?.toString() ?? '',
      storagePath: storagePath,
      publicUrl: storagePath.isEmpty ? '' : publicUrlBuilder(storagePath),
      altText: data['alt_text']?.toString() ?? '',
      sortOrder: _readInteger(data['sort_order']),
    );
  }
}

class AdminBusinessReviewHistory {
  const AdminBusinessReviewHistory({
    required this.id,
    required this.action,
    required this.previousStatus,
    required this.resultingStatus,
    required this.createdAt,
    this.reason,
    this.reviewerId,
    this.reviewerName,
  });

  final String id;
  final String action;
  final String previousStatus;
  final String resultingStatus;
  final String? reason;
  final String? reviewerId;
  final String? reviewerName;
  final DateTime createdAt;

  String get actionLabel {
    return switch (action) {
      'approved' => 'اعتماد النشاط',
      'rejected' => 'رفض النشاط',
      'changes_requested' => 'طلب تعديل',
      _ => 'قرار إداري',
    };
  }

  factory AdminBusinessReviewHistory.fromMap(
    Map<String, dynamic> data, {
    String? reviewerName,
  }) {
    return AdminBusinessReviewHistory(
      id: data['id']?.toString() ?? '',
      action: data['action']?.toString() ?? '',
      previousStatus: data['previous_status']?.toString() ?? '',
      resultingStatus: data['resulting_status']?.toString() ?? '',
      reason: _nullableText(data['reason']),
      reviewerId: _nullableText(data['reviewer_id']),
      reviewerName: _nullableText(reviewerName),
      createdAt: DateTime.tryParse(
            data['created_at']?.toString() ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class AdminBusinessReviewItem {
  const AdminBusinessReviewItem({
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
    required this.isFeatured,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.ownerName,
    this.ownerEmail,
    this.latitude,
    this.longitude,
    this.logoUrl,
    this.coverUrl,
    this.rejectionReason,
    this.images = const <AdminBusinessImage>[],
    this.history = const <AdminBusinessReviewHistory>[],
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
  final bool isFeatured;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ownerName;
  final String? ownerEmail;
  final double? latitude;
  final double? longitude;
  final String? logoUrl;
  final String? coverUrl;
  final String? rejectionReason;
  final List<AdminBusinessImage> images;
  final List<AdminBusinessReviewHistory> history;

  String get displayOwnerName {
    final value = ownerName?.trim();
    return value == null || value.isEmpty ? 'صاحب نشاط غير مسمى' : value;
  }

  String get preferredImageUrl {
    final logo = logoUrl?.trim();
    if (logo != null && logo.isNotEmpty) {
      return logo;
    }
    final cover = coverUrl?.trim();
    if (cover != null && cover.isNotEmpty) {
      return cover;
    }
    for (final image in images) {
      if (image.publicUrl.trim().isNotEmpty) {
        return image.publicUrl.trim();
      }
    }
    return '';
  }

  AdminBusinessReviewItem copyWith({
    String? status,
    String? rejectionReason,
    List<AdminBusinessImage>? images,
    List<AdminBusinessReviewHistory>? history,
    String? ownerName,
    String? ownerEmail,
  }) {
    return AdminBusinessReviewItem(
      id: id,
      ownerId: ownerId,
      categoryId: categoryId,
      categoryName: categoryName,
      name: name,
      description: description,
      phone: phone,
      whatsapp: whatsapp,
      address: address,
      status: status ?? this.status,
      isFeatured: isFeatured,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      latitude: latitude,
      longitude: longitude,
      logoUrl: logoUrl,
      coverUrl: coverUrl,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      images: images ?? this.images,
      history: history ?? this.history,
    );
  }

  factory AdminBusinessReviewItem.fromMap(
    Map<String, dynamic> data, {
    String? ownerName,
    String? ownerEmail,
    List<AdminBusinessImage> images = const <AdminBusinessImage>[],
    List<AdminBusinessReviewHistory> history =
        const <AdminBusinessReviewHistory>[],
  }) {
    final categoryData = data['categories'];
    final category = categoryData is Map<String, dynamic>
        ? categoryData
        : categoryData is Map
            ? Map<String, dynamic>.from(categoryData)
            : const <String, dynamic>{};

    return AdminBusinessReviewItem(
      id: data['id']?.toString() ?? '',
      ownerId: data['owner_id']?.toString() ?? '',
      categoryId: data['category_id']?.toString() ?? '',
      categoryName: category['name_ar']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      whatsapp: data['whatsapp']?.toString() ?? '',
      address: data['address']?.toString() ?? 'الحامي',
      status: data['status']?.toString() ?? 'pending',
      isFeatured: _readBoolean(data['is_featured']),
      isActive: data['is_active'] != false,
      createdAt: DateTime.tryParse(
            data['created_at']?.toString() ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse(
            data['updated_at']?.toString() ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ownerName: _nullableText(ownerName),
      ownerEmail: _nullableText(ownerEmail),
      latitude: _readDouble(data['latitude']),
      longitude: _readDouble(data['longitude']),
      logoUrl: _nullableText(data['logo_url']),
      coverUrl: _nullableText(data['cover_url']),
      rejectionReason: _nullableText(data['rejection_reason']),
      images: images,
      history: history,
    );
  }
}

enum AdminReviewDecision {
  approve,
  reject,
  requestChanges;

  String get rpcValue {
    return switch (this) {
      AdminReviewDecision.approve => 'approve',
      AdminReviewDecision.reject => 'reject',
      AdminReviewDecision.requestChanges => 'request_changes',
    };
  }

  String get resultingStatus {
    return switch (this) {
      AdminReviewDecision.approve => 'approved',
      AdminReviewDecision.reject => 'rejected',
      AdminReviewDecision.requestChanges => 'changes_requested',
    };
  }

  String get label {
    return switch (this) {
      AdminReviewDecision.approve => 'اعتماد',
      AdminReviewDecision.reject => 'رفض',
      AdminReviewDecision.requestChanges => 'طلب تعديل',
    };
  }

  bool get requiresReason => this != AdminReviewDecision.approve;
}

class AdminReviewSubmission {
  const AdminReviewSubmission({
    required this.decision,
    this.reason,
  });

  final AdminReviewDecision decision;
  final String? reason;
}

class AdminBusinessReviewResult {
  const AdminBusinessReviewResult({
    required this.businessId,
    required this.previousStatus,
    required this.resultingStatus,
    required this.decision,
    required this.reviewedAt,
    this.reason,
  });

  final String businessId;
  final String previousStatus;
  final String resultingStatus;
  final String decision;
  final DateTime reviewedAt;
  final String? reason;

  factory AdminBusinessReviewResult.fromRpc(Object? response) {
    final map = _asMap(response);
    return AdminBusinessReviewResult(
      businessId: map['business_id']?.toString() ?? '',
      previousStatus: map['previous_status']?.toString() ?? '',
      resultingStatus: map['resulting_status']?.toString() ?? '',
      decision: map['decision']?.toString() ?? '',
      reviewedAt: DateTime.tryParse(
            map['reviewed_at']?.toString() ?? '',
          )?.toUtc() ??
          DateTime.now().toUtc(),
      reason: _nullableText(map['reason']),
    );
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    if (value is List && value.isNotEmpty && value.first is Map) {
      final map = value.first as Map;
      return map.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    throw const FormatException(
      'Supabase returned an invalid business review result.',
    );
  }
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

String? _nullableText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
