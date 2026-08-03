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
    this.isFeatured = false,
    this.isRemote = false,
    this.createdAt,
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
  final bool isFeatured;
  final bool isRemote;
  final DateTime? createdAt;

  String get preferredImageUrl {
    final cover = coverUrl?.trim() ?? '';
    if (cover.isNotEmpty) {
      return cover;
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

  bool get hasPhone => phone.trim().isNotEmpty;

  bool get hasWhatsApp => whatsappContact.isNotEmpty;

  String get whatsappContact {
    final value = whatsapp.trim();
    return value.isNotEmpty ? value : phone.trim();
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
        whatsapp.contains(normalizedQuery);
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
    bool? isFeatured,
    bool? isRemote,
    DateTime? createdAt,
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
      isFeatured: isFeatured ?? this.isFeatured,
      isRemote: isRemote ?? this.isRemote,
      createdAt: createdAt ?? this.createdAt,
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
      'is_featured': isFeatured,
      'is_remote': isRemote,
      'created_at': createdAt?.toIso8601String(),
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
      isFeatured: map['is_featured'] == true,
      isRemote: map['is_remote'] == true,
      createdAt: DateTime.tryParse(
        map['created_at']?.toString() ?? '',
      ),
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
      isFeatured: data['is_featured'] == true,
      isRemote: true,
      createdAt: DateTime.tryParse(
        data['created_at']?.toString() ?? '',
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

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
