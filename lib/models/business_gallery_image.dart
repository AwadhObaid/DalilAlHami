class BusinessGalleryImage {
  const BusinessGalleryImage({
    required this.id,
    required this.businessId,
    required this.storagePath,
    required this.sortOrder,
    required this.isPrimary,
    this.publicUrl,
    this.altText = '',
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncVersion = 0,
  });

  final String id;
  final String businessId;
  final String storagePath;
  final String? publicUrl;
  final String altText;
  final int sortOrder;
  final bool isPrimary;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int syncVersion;

  bool get isDeleted => deletedAt != null;

  String get displayUrl {
    final value = publicUrl?.trim() ?? '';
    return value.isNotEmpty ? value : storagePath.trim();
  }

  BusinessGalleryImage copyWith({
    String? id,
    String? businessId,
    String? storagePath,
    String? publicUrl,
    bool clearPublicUrl = false,
    String? altText,
    int? sortOrder,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? syncVersion,
  }) {
    return BusinessGalleryImage(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      storagePath: storagePath ?? this.storagePath,
      publicUrl: clearPublicUrl ? null : publicUrl ?? this.publicUrl,
      altText: altText ?? this.altText,
      sortOrder: sortOrder ?? this.sortOrder,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'business_id': businessId,
      'storage_path': storagePath,
      'public_url': publicUrl,
      'alt_text': altText,
      'sort_order': sortOrder,
      'is_primary': isPrimary,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_version': syncVersion,
    };
  }

  factory BusinessGalleryImage.fromMap(Map<String, dynamic> map) {
    return BusinessGalleryImage(
      id: map['id']?.toString() ?? '',
      businessId: map['business_id']?.toString() ?? '',
      storagePath: map['storage_path']?.toString() ?? '',
      publicUrl: _nullableText(map['public_url']),
      altText: map['alt_text']?.toString() ?? '',
      sortOrder: _readInteger(map['sort_order']),
      isPrimary: _readBoolean(map['is_primary']),
      createdAt: _readDate(map['created_at']),
      updatedAt: _readDate(map['updated_at']),
      deletedAt: _readDate(map['deleted_at']),
      syncVersion: _readInteger(map['sync_version']),
    );
  }

  factory BusinessGalleryImage.fromSupabase(Map<String, dynamic> data) {
    return BusinessGalleryImage.fromMap(data);
  }

  static List<BusinessGalleryImage> readList(Object? value) {
    if (value is! List) {
      return const <BusinessGalleryImage>[];
    }

    final images = <BusinessGalleryImage>[];
    for (final item in value) {
      Map<String, dynamic>? map;
      if (item is Map<String, dynamic>) {
        map = item;
      } else if (item is Map) {
        map = Map<String, dynamic>.from(item);
      }
      if (map == null) {
        continue;
      }
      final image = BusinessGalleryImage.fromMap(map);
      if (image.id.isNotEmpty &&
          image.storagePath.isNotEmpty &&
          !image.isDeleted) {
        images.add(image);
      }
    }

    images.sort((first, second) {
      if (first.isPrimary != second.isPrimary) {
        return first.isPrimary ? -1 : 1;
      }
      final order = first.sortOrder.compareTo(second.sortOrder);
      if (order != 0) {
        return order;
      }
      return first.id.compareTo(second.id);
    });
    return List<BusinessGalleryImage>.unmodifiable(images);
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

DateTime? _readDate(Object? value) {
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
