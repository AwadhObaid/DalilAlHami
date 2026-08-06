class DirectoryAdvertisement {
  const DirectoryAdvertisement({
    required this.id,
    required this.title,
    required this.sortOrder,
    this.businessId,
    this.placement = 'home_top',
    this.imagePath,
    this.compactImagePath,
    this.targetUrl,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
    this.updatedAt,
    this.deletedAt,
    this.syncVersion = 0,
  });

  final String id;
  final String title;
  final int sortOrder;
  final String? businessId;
  final String placement;
  final String? imagePath;
  final String? compactImagePath;
  final String? targetUrl;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int syncVersion;

  bool isVisibleAt(DateTime value) {
    final now = value.toUtc();
    if (!isActive || deletedAt != null) {
      return false;
    }

    final start = startsAt?.toUtc();
    if (start != null && start.isAfter(now)) {
      return false;
    }

    final end = endsAt?.toUtc();
    return end == null || end.isAfter(now);
  }

  factory DirectoryAdvertisement.fromSupabase(
    Map<String, dynamic> data,
  ) {
    return DirectoryAdvertisement(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      sortOrder: _readInteger(data['sort_order']),
      businessId: _nullableString(data['business_id']),
      placement: _readPlacement(data['placement']),
      imagePath: _nullableString(data['image_path']),
      compactImagePath: _nullableString(data['compact_image_path']),
      targetUrl: _nullableString(data['target_url']),
      isActive: _readBoolean(data['is_active'], fallback: true),
      startsAt: DateTime.tryParse(
        data['starts_at']?.toString() ?? '',
      ),
      endsAt: DateTime.tryParse(
        data['ends_at']?.toString() ?? '',
      ),
      updatedAt: DateTime.tryParse(
        data['updated_at']?.toString() ?? '',
      ),
      deletedAt: DateTime.tryParse(
        data['deleted_at']?.toString() ?? '',
      ),
      syncVersion: _readInteger(data['sync_version']),
    );
  }

  static String _readPlacement(Object? value) {
    return switch (value?.toString()) {
      'home_middle' => 'home_middle',
      'category' => 'category',
      'business_list' => 'business_list',
      _ => 'home_top',
    };
  }

  static bool _readBoolean(
    Object? value, {
    required bool fallback,
  }) {
    if (value == null) {
      return fallback;
    }

    return value == true || value == 1 || value.toString() == '1';
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
