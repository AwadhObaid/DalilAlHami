import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/business_contact_number.dart';

abstract interface class BusinessContactNumberRepository {
  Future<List<BusinessContactNumber>> fetchForBusiness(String businessId);
  Future<Map<String, List<BusinessContactNumber>>> fetchForBusinesses(
    Iterable<String> businessIds,
  );
}

class SupabaseBusinessContactNumberRepository
    implements BusinessContactNumberRepository {
  const SupabaseBusinessContactNumberRepository(this._client);
  final SupabaseClient _client;

  static const String _selection =
      'id, business_id, phone_number, label, is_primary, '
      'supports_whatsapp, sort_order, created_at, updated_at';

  @override
  Future<List<BusinessContactNumber>> fetchForBusiness(
      String businessId) async {
    final normalizedId = businessId.trim();
    if (normalizedId.isEmpty) return const <BusinessContactNumber>[];

    final rows = await _client
        .from('business_contact_numbers')
        .select(_selection)
        .eq('business_id', normalizedId)
        .isFilter('deleted_at', null)
        .order('sort_order')
        .order('created_at');

    return List<BusinessContactNumber>.unmodifiable(
      rows.map<BusinessContactNumber>(BusinessContactNumber.fromSupabase),
    );
  }

  @override
  Future<Map<String, List<BusinessContactNumber>>> fetchForBusinesses(
    Iterable<String> businessIds,
  ) async {
    final ids = businessIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const <String, List<BusinessContactNumber>>{};

    final rows = await _client
        .from('business_contact_numbers')
        .select(_selection)
        .inFilter('business_id', ids)
        .isFilter('deleted_at', null)
        .order('business_id')
        .order('sort_order')
        .order('created_at');

    final grouped = <String, List<BusinessContactNumber>>{};
    for (final row in rows) {
      final item = BusinessContactNumber.fromSupabase(row);
      grouped
          .putIfAbsent(item.businessId, () => <BusinessContactNumber>[])
          .add(item);
    }

    return Map<String, List<BusinessContactNumber>>.unmodifiable(
      grouped.map((key, value) => MapEntry(
            key,
            List<BusinessContactNumber>.unmodifiable(value),
          )),
    );
  }
}
