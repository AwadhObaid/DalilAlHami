enum AdminAdvertisementPlacement {
  homeTop,
  homeMiddle,
  category,
  businessList;

  String get rpcValue => switch (this) {
        AdminAdvertisementPlacement.homeTop => 'home_top',
        AdminAdvertisementPlacement.homeMiddle => 'home_middle',
        AdminAdvertisementPlacement.category => 'category',
        AdminAdvertisementPlacement.businessList => 'business_list',
      };

  String get label => switch (this) {
        AdminAdvertisementPlacement.homeTop => 'أعلى الصفحة الرئيسية',
        AdminAdvertisementPlacement.homeMiddle => 'وسط الصفحة الرئيسية',
        AdminAdvertisementPlacement.category => 'صفحات الأقسام',
        AdminAdvertisementPlacement.businessList => 'قوائم الأنشطة',
      };

  String get shortLabel => switch (this) {
        AdminAdvertisementPlacement.homeTop => 'الرئيسية — أعلى',
        AdminAdvertisementPlacement.homeMiddle => 'الرئيسية — وسط',
        AdminAdvertisementPlacement.category => 'الأقسام',
        AdminAdvertisementPlacement.businessList => 'قوائم الأنشطة',
      };

  static AdminAdvertisementPlacement fromValue(Object? value) {
    return switch (value?.toString()) {
      'home_middle' => AdminAdvertisementPlacement.homeMiddle,
      'category' => AdminAdvertisementPlacement.category,
      'business_list' => AdminAdvertisementPlacement.businessList,
      _ => AdminAdvertisementPlacement.homeTop,
    };
  }
}

enum AdminAdvertisementTargetType {
  none,
  business,
  external;

  String get label => switch (this) {
        AdminAdvertisementTargetType.none => 'بدون رابط',
        AdminAdvertisementTargetType.business => 'نشاط داخل الدليل',
        AdminAdvertisementTargetType.external => 'رابط خارجي',
      };
}

enum AdminAdvertisementRuntimeState {
  visible,
  scheduled,
  ended,
  inactive;

  String get label => switch (this) {
        AdminAdvertisementRuntimeState.visible => 'ظاهر الآن',
        AdminAdvertisementRuntimeState.scheduled => 'مجدول',
        AdminAdvertisementRuntimeState.ended => 'منتهي',
        AdminAdvertisementRuntimeState.inactive => 'متوقف',
      };
}

class AdminAdvertisementBusinessOption {
  const AdminAdvertisementBusinessOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory AdminAdvertisementBusinessOption.fromMap(
    Map<String, dynamic> data,
  ) {
    return AdminAdvertisementBusinessOption(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
    );
  }
}

class AdminAdvertisementItem {
  const AdminAdvertisementItem({
    required this.id,
    required this.title,
    required this.imagePath,
    required this.placement,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.businessId,
    this.businessName,
    this.targetUrl,
    this.startsAt,
    this.endsAt,
    this.deletedAt,
  });

  final String id;
  final String title;
  final String imagePath;
  final AdminAdvertisementPlacement placement;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? businessId;
  final String? businessName;
  final String? targetUrl;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  AdminAdvertisementTargetType get targetType {
    if (businessId != null && businessId!.trim().isNotEmpty) {
      return AdminAdvertisementTargetType.business;
    }
    if (targetUrl != null && targetUrl!.trim().isNotEmpty) {
      return AdminAdvertisementTargetType.external;
    }
    return AdminAdvertisementTargetType.none;
  }

  String get targetLabel => switch (targetType) {
        AdminAdvertisementTargetType.business =>
          businessName?.trim().isNotEmpty == true
              ? businessName!.trim()
              : 'نشاط داخل الدليل',
        AdminAdvertisementTargetType.external => targetUrl!.trim(),
        AdminAdvertisementTargetType.none => 'بدون رابط',
      };

  AdminAdvertisementRuntimeState runtimeStateAt(DateTime value) {
    final now = value.toUtc();
    if (!isActive || isDeleted) {
      return AdminAdvertisementRuntimeState.inactive;
    }
    final start = startsAt?.toUtc();
    if (start != null && start.isAfter(now)) {
      return AdminAdvertisementRuntimeState.scheduled;
    }
    final end = endsAt?.toUtc();
    if (end != null && !end.isAfter(now)) {
      return AdminAdvertisementRuntimeState.ended;
    }
    return AdminAdvertisementRuntimeState.visible;
  }

  bool isVisibleAt(DateTime value) =>
      runtimeStateAt(value) == AdminAdvertisementRuntimeState.visible;

  factory AdminAdvertisementItem.fromMap(Map<String, dynamic> data) {
    final businessData = data['businesses'];
    final business = businessData is Map<String, dynamic>
        ? businessData
        : businessData is Map
            ? businessData.map(
                (key, value) => MapEntry(key.toString(), value),
              )
            : const <String, dynamic>{};

    return AdminAdvertisementItem(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      imagePath: data['image_path']?.toString() ?? '',
      placement: AdminAdvertisementPlacement.fromValue(data['placement']),
      sortOrder: _readInteger(data['sort_order']),
      isActive: _readBoolean(data['is_active']),
      createdAt: _readDate(data['created_at']),
      updatedAt: _readDate(data['updated_at']),
      businessId: _nullableText(data['business_id']),
      businessName: _nullableText(business['name']),
      targetUrl: _nullableText(data['target_url']),
      startsAt: _readNullableDate(data['starts_at']),
      endsAt: _readNullableDate(data['ends_at']),
      deletedAt: _readNullableDate(data['deleted_at']),
    );
  }
}

class AdminAdvertisementDraft {
  const AdminAdvertisementDraft({
    required this.title,
    required this.imagePath,
    required this.placement,
    required this.sortOrder,
    required this.targetType,
    this.id,
    this.businessId,
    this.targetUrl,
    this.startsAt,
    this.endsAt,
  });

  final String? id;
  final String title;
  final String imagePath;
  final AdminAdvertisementPlacement placement;
  final int sortOrder;
  final AdminAdvertisementTargetType targetType;
  final String? businessId;
  final String? targetUrl;
  final DateTime? startsAt;
  final DateTime? endsAt;

  bool get isEditing => id != null && id!.trim().isNotEmpty;
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
