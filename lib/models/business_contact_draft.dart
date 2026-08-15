import 'business_contact_number.dart';

class BusinessContactDraft {
  const BusinessContactDraft({
    required this.phoneNumber,
    required this.label,
    required this.isPrimary,
    required this.supportsWhatsApp,
    required this.sortOrder,
  });

  static const int minPhoneDigits = 5;
  static const int maxPhoneDigits = 20;

  static const List<String> allowedLabels = <String>[
    'الرئيسي',
    'جوال',
    'هاتف ثابت',
    'المبيعات',
    'الإدارة',
  ];

  final String phoneNumber;
  final String label;
  final bool isPrimary;
  final bool supportsWhatsApp;
  final int sortOrder;

  factory BusinessContactDraft.emptyPrimary() => const BusinessContactDraft(
        phoneNumber: '',
        label: 'الرئيسي',
        isPrimary: true,
        supportsWhatsApp: false,
        sortOrder: 0,
      );

  factory BusinessContactDraft.fromContact(BusinessContactNumber contact) {
    return BusinessContactDraft(
      phoneNumber: contact.phoneNumber,
      label: _normalizeLabel(contact.label, contact.isPrimary),
      isPrimary: contact.isPrimary,
      supportsWhatsApp: contact.supportsWhatsApp,
      sortOrder: contact.sortOrder,
    );
  }

  BusinessContactDraft copyWith({
    String? phoneNumber,
    String? label,
    bool? isPrimary,
    bool? supportsWhatsApp,
    int? sortOrder,
  }) {
    return BusinessContactDraft(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      label: label ?? this.label,
      isPrimary: isPrimary ?? this.isPrimary,
      supportsWhatsApp: supportsWhatsApp ?? this.supportsWhatsApp,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toPayloadMap() => <String, dynamic>{
        'phone_number': phoneNumber.trim(),
        'label': label.trim(),
        'is_primary': isPrimary,
        'supports_whatsapp': supportsWhatsApp,
        'sort_order': sortOrder,
      };

  BusinessContactNumber toLocalContactNumber({
    required String businessId,
    required int index,
  }) {
    return BusinessContactNumber(
      id: 'local-$businessId-contact-$index',
      businessId: businessId,
      phoneNumber: phoneNumber.trim(),
      label: label.trim(),
      isPrimary: isPrimary,
      supportsWhatsApp: supportsWhatsApp,
      sortOrder: index,
    );
  }

  static List<BusinessContactDraft> fromExisting({
    required List<BusinessContactNumber> contacts,
    required String legacyPhone,
    required String legacyWhatsApp,
  }) {
    if (contacts.isNotEmpty) {
      return normalizePrimaryForEditing(
        contacts
            .take(BusinessContactNumber.maxPerBusiness)
            .map(BusinessContactDraft.fromContact)
            .toList(growable: false),
      );
    }

    return fromLegacyFields(
      legacyPhone: legacyPhone,
      legacyWhatsApp: legacyWhatsApp,
    );
  }

  static List<BusinessContactDraft> fromLegacyFields({
    required String legacyPhone,
    required String legacyWhatsApp,
    bool defaultWhatsAppToPrimary = false,
  }) {
    final phones = legacyPhone
        .split(RegExp(r'\s*[-–—]{2,}\s*'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(BusinessContactNumber.maxPerBusiness)
        .toList(growable: true);

    final whatsapp = legacyWhatsApp.trim();
    if (phones.isEmpty && whatsapp.isNotEmpty) {
      phones.add(whatsapp);
    }
    if (phones.isEmpty) {
      return <BusinessContactDraft>[BusinessContactDraft.emptyPrimary()];
    }

    final explicitWhatsAppKey = normalizePhoneKey(whatsapp);
    final fallbackWhatsAppKey =
        defaultWhatsAppToPrimary && explicitWhatsAppKey.isEmpty
            ? normalizePhoneKey(phones.first)
            : explicitWhatsAppKey;

    final drafts = <BusinessContactDraft>[];
    for (var index = 0; index < phones.length; index++) {
      final phone = phones[index];
      drafts.add(
        BusinessContactDraft(
          phoneNumber: phone,
          label: index == 0 ? 'الرئيسي' : 'جوال',
          isPrimary: index == 0,
          supportsWhatsApp: fallbackWhatsAppKey.isNotEmpty &&
              normalizePhoneKey(phone) == fallbackWhatsAppKey,
          sortOrder: index,
        ),
      );
    }

    if (explicitWhatsAppKey.isNotEmpty &&
        !drafts.any(
          (item) => normalizePhoneKey(item.phoneNumber) == explicitWhatsAppKey,
        ) &&
        drafts.length < BusinessContactNumber.maxPerBusiness) {
      drafts.add(
        BusinessContactDraft(
          phoneNumber: whatsapp,
          label: 'جوال',
          isPrimary: false,
          supportsWhatsApp: true,
          sortOrder: drafts.length,
        ),
      );
    }

    return normalizePrimaryForEditing(drafts);
  }

  static List<BusinessContactDraft> normalizePrimaryForEditing(
    List<BusinessContactDraft> values,
  ) {
    if (values.isEmpty) {
      return <BusinessContactDraft>[BusinessContactDraft.emptyPrimary()];
    }

    final limited = values.take(BusinessContactNumber.maxPerBusiness).toList();
    var primaryIndex = limited.indexWhere((item) => item.isPrimary);
    if (primaryIndex < 0) primaryIndex = 0;

    var whatsappIndex = limited.indexWhere((item) => item.supportsWhatsApp);

    return <BusinessContactDraft>[
      for (var index = 0; index < limited.length; index++)
        limited[index].copyWith(
          label: _normalizeLabel(limited[index].label, index == primaryIndex),
          isPrimary: index == primaryIndex,
          supportsWhatsApp: index == whatsappIndex,
          sortOrder: index,
        ),
    ];
  }

  static List<BusinessContactDraft> normalizeAndValidate(
    List<BusinessContactDraft> values,
  ) {
    if (values.isEmpty ||
        values.length > BusinessContactNumber.maxPerBusiness) {
      throw const BusinessContactDraftValidationException(
        'يجب إضافة رقم واحد على الأقل وبحد أقصى 5 أرقام.',
      );
    }

    final seen = <String>{};
    var primaryCount = 0;
    var whatsappCount = 0;
    final normalized = <BusinessContactDraft>[];

    for (var index = 0; index < values.length; index++) {
      final item = values[index];
      final phone = item.phoneNumber.trim();
      final key = normalizePhoneKey(phone);
      final digitCount = key.replaceAll('+', '').length;
      if (digitCount < minPhoneDigits || digitCount > maxPhoneDigits) {
        throw const BusinessContactDraftValidationException(
          'تأكد من صحة جميع أرقام التواصل.',
        );
      }
      if (!seen.add(key)) {
        throw const BusinessContactDraftValidationException(
          'لا يمكن تكرار رقم التواصل نفسه داخل النشاط.',
        );
      }
      if (item.isPrimary) primaryCount++;
      if (item.supportsWhatsApp) whatsappCount++;

      normalized.add(
        item.copyWith(
          phoneNumber: phone,
          label: _normalizeLabel(item.label, item.isPrimary),
          sortOrder: index,
        ),
      );
    }

    if (primaryCount != 1) {
      throw const BusinessContactDraftValidationException(
        'حدد رقمًا رئيسيًا واحدًا فقط للنشاط.',
      );
    }
    if (whatsappCount > 1) {
      throw const BusinessContactDraftValidationException(
        'يمكن تحديد رقم واتساب واحد فقط للنشاط.',
      );
    }

    return List<BusinessContactDraft>.unmodifiable(normalized);
  }

  static String primaryPhone(List<BusinessContactDraft> values) {
    for (final item in values) {
      if (item.isPrimary) return item.phoneNumber.trim();
    }
    return values.isEmpty ? '' : values.first.phoneNumber.trim();
  }

  static String whatsappPhone(List<BusinessContactDraft> values) {
    for (final item in values) {
      if (item.supportsWhatsApp) return item.phoneNumber.trim();
    }
    return '';
  }

  static String normalizePhoneKey(String value) {
    return value.trim().replaceAll(RegExp(r'[^0-9+]'), '');
  }

  static String _normalizeLabel(String value, bool isPrimary) {
    final trimmed = value.trim();
    if (allowedLabels.contains(trimmed)) return trimmed;
    return isPrimary ? 'الرئيسي' : 'جوال';
  }
}

class BusinessContactDraftValidationException implements Exception {
  const BusinessContactDraftValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
