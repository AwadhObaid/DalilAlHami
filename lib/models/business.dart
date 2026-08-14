import '../core/location/business_location.dart';
import 'business_gallery_image.dart';
import 'business_contact_number.dart';

class Business {
  const Business({
    required this.id,
    required this.name,
    required this.phone,
    required this.category,
    required this.place,
    this.whatsapp = '',
    this.details = '',
    this.imagePath,
    this.categoryId = '',
    this.categorySlug = '',
    this.logoUrl,
    this.coverUrl,
    this.latitude,
    this.longitude,
    this.isFeatured = false,
    this.isRemote = false,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncVersion = 0,
    this.galleryImages = const <BusinessGalleryImage>[],
    this.contactNumbers = const <BusinessContactNumber>[],
  });

  final String id;
  final String name;
  final String phone;
  final String whatsapp;
  final String category;
  final String place;
  final String details;
  final String? imagePath;
  final String categoryId;
  final String categorySlug;
  final String? logoUrl;
  final String? coverUrl;
  final double? latitude;
  final double? longitude;
  final bool isFeatured;
  final bool isRemote;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int syncVersion;
  final List<BusinessGalleryImage> galleryImages;
  final List<BusinessContactNumber> contactNumbers;

  BusinessLocation? get location =>
      BusinessLocation.fromNullable(latitude, longitude);

  bool get hasLocation => location != null;

  List<BusinessGalleryImage> get activeGalleryImages =>
      BusinessGalleryImage.readList(
        galleryImages.map((image) => image.toMap()).toList(growable: false),
      );

  BusinessGalleryImage? get primaryGalleryImage {
    final images = activeGalleryImages;
    for (final image in images) {
      if (image.isPrimary) {
        return image;
      }
    }
    return images.isEmpty ? null : images.first;
  }

  String get preferredImageUrl {
    final cover = coverUrl?.trim() ?? '';
    if (cover.isNotEmpty) {
      return cover;
    }

    final gallery = primaryGalleryImage?.displayUrl.trim() ?? '';
    if (gallery.isNotEmpty) {
      return gallery;
    }

    return logoUrl?.trim() ?? '';
  }

  String get displayName {
    final value = name.trim();
    return value.isEmpty ? 'نشاط بدون اسم' : value;
  }

  String get displayCategory {
    final value = category.trim();
    return value.isEmpty ? 'خدمات أخرى' : value;
  }

  String get displayPlace {
    final value = place.trim();
    return value.isEmpty ? 'الحامي' : value;
  }

  String get displayDetails => details.trim();

  List<BusinessContactNumber> get activeContactNumbers =>
      BusinessContactNumber.readList(
        contactNumbers
            .map((contact) => contact.toMap())
            .toList(growable: false),
      );

  List<BusinessContactNumber> get effectiveContactNumbers {
    final normalizedContacts = activeContactNumbers;
    if (normalizedContacts.isNotEmpty) {
      return normalizedContacts;
    }

    final legacyPhone = phone.trim();
    if (legacyPhone.isEmpty) {
      return const <BusinessContactNumber>[];
    }

    final legacyWhatsApp = whatsapp.trim();
    return List<BusinessContactNumber>.unmodifiable(
      <BusinessContactNumber>[
        BusinessContactNumber(
          id: 'legacy-phone-$id',
          businessId: id,
          phoneNumber: legacyPhone,
          label: 'الرئيسي',
          isPrimary: true,
          supportsWhatsApp:
              legacyWhatsApp.isEmpty || legacyWhatsApp == legacyPhone,
        ),
      ],
    );
  }

  BusinessContactNumber? get primaryContactNumber {
    final contacts = effectiveContactNumbers;
    return contacts.isEmpty ? null : contacts.first;
  }

  BusinessContactNumber? get whatsappContactNumber {
    for (final contact in effectiveContactNumbers) {
      if (contact.supportsWhatsApp) {
        return contact;
      }
    }
    return null;
  }

  String get phoneContact =>
      primaryContactNumber?.trimmedPhoneNumber ?? phone.trim();

  bool get hasPhone => phoneContact.isNotEmpty;

  bool get hasMultiplePhoneNumbers => effectiveContactNumbers.length > 1;

  bool get hasWhatsApp => whatsappContact.isNotEmpty;

  bool get isDeleted => deletedAt != null;

  String get whatsappContact {
    final normalized = whatsappContactNumber?.trimmedPhoneNumber ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }

    final legacyWhatsApp = whatsapp.trim();
    return legacyWhatsApp.isNotEmpty ? legacyWhatsApp : phoneContact;
  }

  bool matchesSearch(String query) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return false;
    }

    return _normalizeSearchText(name).contains(normalizedQuery) ||
        _normalizeSearchText(category).contains(normalizedQuery) ||
        _normalizeSearchText(place).contains(normalizedQuery) ||
        _normalizeSearchText(details).contains(normalizedQuery) ||
        phone.contains(normalizedQuery) ||
        whatsapp.contains(normalizedQuery) ||
        effectiveContactNumbers.any(
          (contact) => contact.trimmedPhoneNumber.contains(normalizedQuery),
        ) ||
        whatsappContact.contains(normalizedQuery);
  }

  bool belongsToCategory({
    required String id,
    required String name,
  }) {
    if (categoryId.isNotEmpty && id.isNotEmpty) {
      return categoryId == id;
    }

    return category == name;
  }

  Business copyWith({
    String? id,
    String? name,
    String? phone,
    String? whatsapp,
    String? category,
    String? place,
    String? details,
    String? imagePath,
    bool clearImagePath = false,
    String? categoryId,
    String? categorySlug,
    String? logoUrl,
    String? coverUrl,
    double? latitude,
    double? longitude,
    bool clearLocation = false,
    bool? isFeatured,
    bool? isRemote,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? syncVersion,
    List<BusinessGalleryImage>? galleryImages,
    List<BusinessContactNumber>? contactNumbers,
  }) {
    return Business(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      category: category ?? this.category,
      place: place ?? this.place,
      details: details ?? this.details,
      imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
      categoryId: categoryId ?? this.categoryId,
      categorySlug: categorySlug ?? this.categorySlug,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      latitude: clearLocation ? null : latitude ?? this.latitude,
      longitude: clearLocation ? null : longitude ?? this.longitude,
      isFeatured: isFeatured ?? this.isFeatured,
      isRemote: isRemote ?? this.isRemote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
      syncVersion: syncVersion ?? this.syncVersion,
      galleryImages: galleryImages ?? this.galleryImages,
      contactNumbers: contactNumbers ?? this.contactNumbers,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'whatsapp': whatsapp,
      'category': category,
      'place': place,
      'details': details,
      'image_path': imagePath,
      'category_id': categoryId,
      'category_slug': categorySlug,
      'logo_url': logoUrl,
      'cover_url': coverUrl,
      'latitude': latitude,
      'longitude': longitude,
      'is_featured': isFeatured,
      'is_remote': isRemote,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_version': syncVersion,
      'business_images':
          galleryImages.map((image) => image.toMap()).toList(growable: false),
    };
  }

  factory Business.fromMap(Map<String, dynamic> map) {
    return Business(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      whatsapp: map['whatsapp']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      place: map['place']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
      imagePath: _nullableString(map['image_path']),
      categoryId: map['category_id']?.toString() ?? '',
      categorySlug: map['category_slug']?.toString() ?? '',
      logoUrl: _nullableString(map['logo_url']),
      coverUrl: _nullableString(map['cover_url']),
      latitude: _readDouble(map['latitude']),
      longitude: _readDouble(map['longitude']),
      isFeatured: _readBoolean(map['is_featured']),
      isRemote: _readBoolean(map['is_remote']),
      createdAt: DateTime.tryParse(
        map['created_at']?.toString() ?? '',
      ),
      updatedAt: DateTime.tryParse(
        map['updated_at']?.toString() ?? '',
      ),
      deletedAt: DateTime.tryParse(
        map['deleted_at']?.toString() ?? '',
      ),
      syncVersion: _readInteger(map['sync_version']),
      galleryImages: BusinessGalleryImage.readList(map['business_images']),
    );
  }

  factory Business.fromSupabase(Map<String, dynamic> data) {
    final categoryData = data['categories'];
    final categoryMap = categoryData is Map<String, dynamic>
        ? categoryData
        : categoryData is Map
            ? Map<String, dynamic>.from(categoryData)
            : const <String, dynamic>{};

    return Business(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      whatsapp: data['whatsapp']?.toString() ?? '',
      category: categoryMap['name_ar']?.toString() ?? '',
      place: data['address']?.toString() ?? 'الحامي',
      details: data['description']?.toString() ?? '',
      categoryId: data['category_id']?.toString() ?? '',
      categorySlug: categoryMap['slug']?.toString() ?? '',
      logoUrl: _nullableString(data['logo_url']),
      coverUrl: _nullableString(data['cover_url']),
      latitude: _readDouble(data['latitude']),
      longitude: _readDouble(data['longitude']),
      isFeatured: _readBoolean(data['is_featured']),
      isRemote: true,
      createdAt: DateTime.tryParse(
        data['created_at']?.toString() ?? '',
      ),
      updatedAt: DateTime.tryParse(
        data['updated_at']?.toString() ?? '',
      ),
      deletedAt: DateTime.tryParse(
        data['deleted_at']?.toString() ?? '',
      ),
      syncVersion: _readInteger(data['sync_version']),
      galleryImages: BusinessGalleryImage.readList(data['business_images']),
      contactNumbers: BusinessContactNumber.readList(
        data['business_contact_numbers'],
      ),
    );
  }

  static String _normalizeSearchText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ة', 'ه');
  }

  static bool _readBoolean(Object? value) {
    return value == true || value == 1 || value?.toString() == '1';
  }

  static double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  static int _readInteger(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
