import 'business_gallery_image.dart';

class AdminMediaOverview {
  const AdminMediaOverview({
    required this.profileAvatars,
    required this.categoryImages,
    required this.businessLogos,
    required this.businessCovers,
    required this.galleryImages,
    required this.advertisementImages,
    required this.compactAdvertisementImages,
    required this.draftObjects,
    required this.recentGallery,
  });

  final int profileAvatars;
  final int categoryImages;
  final int businessLogos;
  final int businessCovers;
  final int galleryImages;
  final int advertisementImages;
  final int compactAdvertisementImages;
  final int draftObjects;
  final List<AdminRecentGalleryImage> recentGallery;

  int get totalReferencedImages =>
      profileAvatars +
      categoryImages +
      businessLogos +
      businessCovers +
      galleryImages +
      advertisementImages +
      compactAdvertisementImages;

  factory AdminMediaOverview.fromRpc(Object? response) {
    final data = _readMap(response);
    return AdminMediaOverview(
      profileAvatars: _readInteger(data['profile_avatars']),
      categoryImages: _readInteger(data['category_images']),
      businessLogos: _readInteger(data['business_logos']),
      businessCovers: _readInteger(data['business_covers']),
      galleryImages: _readInteger(data['gallery_images']),
      advertisementImages: _readInteger(data['advertisement_images']),
      compactAdvertisementImages: _readInteger(
        data['compact_advertisement_images'],
      ),
      draftObjects: _readInteger(data['draft_objects']),
      recentGallery: _readList(data['recent_gallery'])
          .map(AdminRecentGalleryImage.fromMap)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class AdminRecentGalleryImage {
  const AdminRecentGalleryImage({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.storagePath,
    required this.publicUrl,
    required this.altText,
    required this.sortOrder,
    required this.isPrimary,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String storagePath;
  final String publicUrl;
  final String altText;
  final int sortOrder;
  final bool isPrimary;
  final DateTime? updatedAt;

  BusinessGalleryImage get galleryImage => BusinessGalleryImage(
        id: id,
        businessId: businessId,
        storagePath: storagePath,
        publicUrl: publicUrl,
        altText: altText,
        sortOrder: sortOrder,
        isPrimary: isPrimary,
        updatedAt: updatedAt,
      );

  factory AdminRecentGalleryImage.fromMap(Map<String, dynamic> data) {
    return AdminRecentGalleryImage(
      id: data['id']?.toString() ?? '',
      businessId: data['business_id']?.toString() ?? '',
      businessName: data['business_name']?.toString() ?? 'نشاط غير مسمى',
      storagePath: data['storage_path']?.toString() ?? '',
      publicUrl: data['public_url']?.toString() ?? '',
      altText: data['alt_text']?.toString() ?? '',
      sortOrder: _readInteger(data['sort_order']),
      isPrimary: _readBoolean(data['is_primary']),
      updatedAt: _readDate(data['updated_at']),
    );
  }
}

class AdminMediaCleanupCandidate {
  const AdminMediaCleanupCandidate({
    required this.bucketId,
    required this.storagePath,
    required this.reason,
    this.createdAt,
  });

  final String bucketId;
  final String storagePath;
  final String reason;
  final DateTime? createdAt;

  bool get isExpiredDraft => reason == 'expired_draft';
  String get reasonLabel => isExpiredDraft ? 'مسودة منتهية' : 'ملف غير مستخدم';

  factory AdminMediaCleanupCandidate.fromMap(Map<String, dynamic> data) {
    return AdminMediaCleanupCandidate(
      bucketId: data['bucket_id']?.toString() ?? '',
      storagePath: data['storage_path']?.toString() ?? '',
      reason: data['reason']?.toString() ?? 'unreferenced',
      createdAt: _readDate(data['created_at']),
    );
  }

  static List<AdminMediaCleanupCandidate> readList(Object? value) {
    return _readList(value)
        .map(AdminMediaCleanupCandidate.fromMap)
        .where(
            (item) => item.bucketId.isNotEmpty && item.storagePath.isNotEmpty)
        .toList(growable: false);
  }
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  if (value is List && value.isNotEmpty) {
    return _readMap(value.first);
  }
  throw const FormatException('Supabase returned invalid media data.');
}

List<Map<String, dynamic>> _readList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((item) => item.map((key, entry) => MapEntry(key.toString(), entry)))
      .toList(growable: false);
}

int _readInteger(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _readBoolean(Object? value) {
  return value == true || value == 1 || value?.toString() == '1';
}

DateTime? _readDate(Object? value) {
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value?.toString() ?? '');
}
