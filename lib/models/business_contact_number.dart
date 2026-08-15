class BusinessContactNumber {
  const BusinessContactNumber({
    required this.id,
    required this.businessId,
    required this.phoneNumber,
    this.label = '',
    this.isPrimary = false,
    this.supportsWhatsApp = false,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncVersion = 0,
  });

  static const int maxPerBusiness = 5;

  final String id;
  final String businessId;
  final String phoneNumber;
  final String label;
  final bool isPrimary;
  final bool supportsWhatsApp;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int syncVersion;

  String get trimmedPhoneNumber => phoneNumber.trim();
  bool get hasPhoneNumber => trimmedPhoneNumber.isNotEmpty;
  bool get isDeleted => deletedAt != null;

  String get displayLabel {
    final value = label.trim();
    if (value.isNotEmpty) return value;
    return isPrimary ? 'الرئيسي' : 'رقم الاتصال';
  }

  BusinessContactNumber copyWith({
    String? id,
    String? businessId,
    String? phoneNumber,
    String? label,
    bool? isPrimary,
    bool? supportsWhatsApp,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? syncVersion,
  }) {
    return BusinessContactNumber(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      label: label ?? this.label,
      isPrimary: isPrimary ?? this.isPrimary,
      supportsWhatsApp: supportsWhatsApp ?? this.supportsWhatsApp,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  factory BusinessContactNumber.fromSupabase(Map<String, dynamic> data) {
    return BusinessContactNumber(
      id: data['id']?.toString() ?? '',
      businessId: data['business_id']?.toString() ?? '',
      phoneNumber: data['phone_number']?.toString() ?? '',
      label: data['label']?.toString() ?? '',
      isPrimary: data['is_primary'] == true,
      supportsWhatsApp: data['supports_whatsapp'] == true,
      sortOrder: _readInt(data['sort_order']),
      createdAt: _readDateTime(data['created_at']),
      updatedAt: _readDateTime(data['updated_at']),
      deletedAt: _readDateTime(data['deleted_at']),
      syncVersion: _readInt(data['sync_version']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'business_id': businessId,
        'phone_number': phoneNumber,
        'label': label,
        'is_primary': isPrimary,
        'supports_whatsapp': supportsWhatsApp,
        'sort_order': sortOrder,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'sync_version': syncVersion,
      };

  static List<BusinessContactNumber> readList(
    Object? value, {
    bool includeDeleted = false,
  }) {
    if (value is! List) return const <BusinessContactNumber>[];

    final contacts = value
        .whereType<Map>()
        .map(
          (item) => BusinessContactNumber.fromSupabase(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((item) => item.id.isNotEmpty && item.hasPhoneNumber)
        .where((item) => includeDeleted || !item.isDeleted)
        .toList(growable: false)
      ..sort((a, b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) return order;
        return a.phoneNumber.compareTo(b.phoneNumber);
      });

    return List<BusinessContactNumber>.unmodifiable(
      contacts.take(maxPerBusiness),
    );
  }

  static List<BusinessContactNumber> resolveEffective({
    required String businessId,
    required Iterable<BusinessContactNumber> contacts,
    String legacyPhone = '',
    String legacyWhatsApp = '',
  }) {
    final modernContacts = readList(
      contacts.map((contact) => contact.toMap()).toList(growable: false),
    );
    if (modernContacts.isNotEmpty) {
      return modernContacts;
    }

    final phone = legacyPhone.trim();
    final whatsapp = legacyWhatsApp.trim();
    if (phone.isEmpty) {
      return const <BusinessContactNumber>[];
    }

    final phoneKey = _normalizePhoneKey(phone);
    final whatsappKey = _normalizePhoneKey(whatsapp);
    final sameNumber =
        whatsapp.isNotEmpty && phoneKey.isNotEmpty && phoneKey == whatsappKey;

    return List<BusinessContactNumber>.unmodifiable(
      <BusinessContactNumber>[
        BusinessContactNumber(
          id: 'legacy-phone-$businessId',
          businessId: businessId,
          phoneNumber: phone,
          label: 'الرئيسي',
          isPrimary: true,
          supportsWhatsApp: whatsapp.isEmpty || sameNumber,
          sortOrder: 0,
        ),
      ],
    );
  }

  static String _normalizePhoneKey(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static int _readInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _readDateTime(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text)?.toUtc();
  }
}
