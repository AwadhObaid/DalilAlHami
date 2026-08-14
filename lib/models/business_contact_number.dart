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

  String get trimmedPhoneNumber => phoneNumber.trim();
  bool get hasPhoneNumber => trimmedPhoneNumber.isNotEmpty;
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
  }) =>
      BusinessContactNumber(
        id: id ?? this.id,
        businessId: businessId ?? this.businessId,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        label: label ?? this.label,
        isPrimary: isPrimary ?? this.isPrimary,
        supportsWhatsApp: supportsWhatsApp ?? this.supportsWhatsApp,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

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
    );
  }

  static int _readInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _readDateTime(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}
