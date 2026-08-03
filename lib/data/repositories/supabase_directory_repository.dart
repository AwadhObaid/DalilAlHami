import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/business.dart';
import '../../models/service_category.dart';
import '../sync/directory_sync_delta.dart';
import 'directory_repository.dart';
import 'directory_sync_repository.dart';

class SupabaseDirectoryRepository
    implements DirectoryRepository, DirectorySyncRepository {
  const SupabaseDirectoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ServiceCategory>> fetchCategories() async {
    final rows = await _client
        .from('categories')
        .select(
          'id, name_ar, slug, icon_name, image_url, '
          'sort_order, display_group, updated_at, deleted_at, '
          'sync_version',
        )
        .eq('is_active', true)
        .order('sort_order');

    return rows
        .map<ServiceCategory>(
          ServiceCategory.fromSupabase,
        )
        .toList(growable: false);
  }

  @override
  Future<List<Business>> fetchApprovedBusinesses() async {
    final rows = await _client
        .from('businesses')
        .select(
          'id, category_id, name, description, phone, whatsapp, '
          'address, logo_url, cover_url, is_featured, created_at, '
          'updated_at, deleted_at, sync_version, '
          'categories!businesses_category_id_fkey('
          'id, name_ar, slug, icon_name'
          ')',
        )
        .eq('status', 'approved')
        .eq('is_active', true)
        .order('is_featured', ascending: false)
        .order('created_at', ascending: false);

    return rows
        .map<Business>(
          Business.fromSupabase,
        )
        .toList(growable: false);
  }

  @override
  Future<DirectorySyncDelta> fetchChanges({
    required int afterVersion,
  }) async {
    final response = await _client.rpc(
      'get_directory_changes',
      params: {
        'p_after_version': afterVersion,
      },
    );

    return DirectorySyncDelta.fromRpc(response);
  }
}
