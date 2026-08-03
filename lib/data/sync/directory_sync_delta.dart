import '../../models/business.dart';
import '../../models/directory_advertisement.dart';
import '../../models/service_category.dart';

class DirectorySyncDelta {
  const DirectorySyncDelta({
    required this.serverVersion,
    required this.isFullSnapshot,
    this.categories = const [],
    this.deletedCategoryIds = const {},
    this.businesses = const [],
    this.deletedBusinessIds = const {},
    this.advertisements = const [],
    this.deletedAdvertisementIds = const {},
  });

  final int serverVersion;
  final bool isFullSnapshot;
  final List<ServiceCategory> categories;
  final Set<String> deletedCategoryIds;
  final List<Business> businesses;
  final Set<String> deletedBusinessIds;
  final List<DirectoryAdvertisement> advertisements;
  final Set<String> deletedAdvertisementIds;

  int get changeCount =>
      categories.length +
      deletedCategoryIds.length +
      businesses.length +
      deletedBusinessIds.length +
      advertisements.length +
      deletedAdvertisementIds.length;

  bool get hasChanges => isFullSnapshot || changeCount > 0;

  factory DirectorySyncDelta.fromRpc(Object? response) {
    final data = _readMap(response);

    return DirectorySyncDelta(
      serverVersion: _readInteger(data['server_version']),
      isFullSnapshot: _readBoolean(data['is_full_snapshot']),
      categories: _readRows(data['categories'])
          .map(ServiceCategory.fromSupabase)
          .where((category) => category.id.isNotEmpty)
          .toList(growable: false),
      deletedCategoryIds: _readIds(
        data['deleted_category_ids'],
      ),
      businesses: _readRows(data['businesses'])
          .map(Business.fromSupabase)
          .where((business) => business.id.isNotEmpty)
          .toList(growable: false),
      deletedBusinessIds: _readIds(
        data['deleted_business_ids'],
      ),
      advertisements: _readRows(data['advertisements'])
          .map(DirectoryAdvertisement.fromSupabase)
          .where((advertisement) => advertisement.id.isNotEmpty)
          .toList(growable: false),
      deletedAdvertisementIds: _readIds(
        data['deleted_advertisement_ids'],
      ),
    );
  }

  static Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const FormatException(
      'Supabase incremental sync returned an invalid response.',
    );
  }

  static List<Map<String, dynamic>> _readRows(Object? value) {
    if (value is! List) {
      return const [];
    }

    final rows = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        rows.add(item);
      } else if (item is Map) {
        rows.add(Map<String, dynamic>.from(item));
      }
    }

    return rows;
  }

  static Set<String> _readIds(Object? value) {
    if (value is! List) {
      return const {};
    }

    return Set<String>.unmodifiable(
      value
          .map((item) => item?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty),
    );
  }

  static int _readInteger(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBoolean(Object? value) {
    return value == true || value == 1 || value?.toString() == '1';
  }
}
