import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../models/admin_advertisement_management.dart';
import '../../models/admin_content_management.dart';
import 'admin_repository.dart';

class AdminContentRepository {
  final AdminRepository _adminRepository = AdminRepository();

  SupabaseClient get _client => SupabaseService.client;

  Future<List<AdminCategoryItem>> loadCategories() async {
    await _adminRepository.loadCurrentAdminProfile();

    final categoryRows = _asRows(
      await _client.from('categories').select(
            'id, name_ar, slug, icon_name, image_url, sort_order, '
            'display_group, is_active, deleted_at, updated_at',
          ),
    );
    final businessRows = _asRows(
      await _client.from('businesses').select(
            'id, category_id, status, is_active, deleted_at',
          ),
    );

    final result = categoryRows.map((category) {
      final categoryId = category['id']?.toString() ?? '';
      final linked = businessRows.where(
        (business) => business['category_id']?.toString() == categoryId,
      );
      final visible = linked.where(
        (business) => business['deleted_at'] == null,
      );
      final active = visible.where(
        (business) =>
            business['is_active'] != false &&
            business['status']?.toString() == 'approved',
      );
      return AdminCategoryItem.fromMap(
        category,
        businessCount: linked.length,
        activeBusinessCount: active.length,
      );
    }).toList(growable: false)
      ..sort((left, right) {
        final order = left.sortOrder.compareTo(right.sortOrder);
        if (order != 0) return order;
        return left.name.compareTo(right.name);
      });

    return result;
  }

  Future<List<AdminBusinessItem>> loadBusinesses() async {
    await _adminRepository.loadCurrentAdminProfile();

    final businessRows = _asRows(
      await _client
          .from('businesses')
          .select(
            'id, owner_id, category_id, name, description, phone, whatsapp, '
            'address, latitude, longitude, logo_url, cover_url, status, '
            'rejection_reason, is_featured, is_active, deleted_at, '
            'created_at, updated_at, '
            'categories!businesses_category_id_fkey(id, name_ar, slug)',
          )
          .order('updated_at', ascending: false),
    );
    final profileRows = _asRows(
      await _client.from('profiles').select('id, full_name, email'),
    );
    final profiles = <String, Map<String, dynamic>>{
      for (final row in profileRows)
        if ((row['id']?.toString() ?? '').isNotEmpty) row['id'].toString(): row,
    };

    return businessRows.map((business) {
      final ownerId = business['owner_id']?.toString() ?? '';
      final owner = profiles[ownerId];
      return AdminBusinessItem.fromMap(
        business,
        ownerName: owner?['full_name']?.toString(),
        ownerEmail: owner?['email']?.toString(),
      );
    }).toList(growable: false);
  }

  Future<AdminContentMutationResult> saveCategory(
    AdminCategoryDraft draft,
  ) async {
    await _adminRepository.loadCurrentAdminProfile();
    try {
      final response = await _client.rpc(
        'admin_upsert_category',
        params: <String, dynamic>{
          'p_category_id': draft.id,
          'p_name_ar': draft.name.trim(),
          'p_slug': draft.slug.trim().toLowerCase(),
          'p_icon_name': draft.iconName.trim(),
          'p_image_url': _nullable(draft.imageUrl),
          'p_sort_order': draft.sortOrder,
          'p_display_group': draft.displayGroup,
        },
      );
      return AdminContentMutationResult.fromRpc(response);
    } on PostgrestException catch (error) {
      throw AdminContentRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<AdminContentMutationResult> setCategoryActive({
    required String categoryId,
    required bool isActive,
  }) async {
    await _adminRepository.loadCurrentAdminProfile();
    try {
      final response = await _client.rpc(
        'admin_set_category_active',
        params: <String, dynamic>{
          'p_category_id': categoryId,
          'p_is_active': isActive,
        },
      );
      return AdminContentMutationResult.fromRpc(response);
    } on PostgrestException catch (error) {
      throw AdminContentRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<AdminContentMutationResult> deleteCategory(String categoryId) async {
    await _adminRepository.loadCurrentAdminProfile();
    try {
      final response = await _client.rpc(
        'admin_delete_category',
        params: <String, dynamic>{'p_category_id': categoryId},
      );
      return AdminContentMutationResult.fromRpc(response);
    } on PostgrestException catch (error) {
      throw AdminContentRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<AdminContentMutationResult> saveBusiness(
    AdminBusinessDraft draft,
  ) async {
    await _adminRepository.loadCurrentAdminProfile();
    try {
      final response = await _client.rpc(
        'admin_upsert_business',
        params: <String, dynamic>{
          'p_business_id': draft.id,
          'p_category_id': draft.categoryId,
          'p_name': draft.name.trim(),
          'p_description': draft.description.trim(),
          'p_phone': draft.phone.trim(),
          'p_whatsapp': draft.whatsapp.trim(),
          'p_address': draft.address.trim(),
          'p_latitude': draft.latitude,
          'p_longitude': draft.longitude,
          'p_logo_url': _nullable(draft.logoUrl),
          'p_cover_url': _nullable(draft.coverUrl),
        },
      );
      return AdminContentMutationResult.fromRpc(response);
    } on PostgrestException catch (error) {
      throw AdminContentRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<AdminContentMutationResult> manageBusiness({
    required String businessId,
    required AdminBusinessManagementAction action,
    String? reason,
  }) async {
    await _adminRepository.loadCurrentAdminProfile();
    try {
      final response = await _client.rpc(
        'admin_manage_business',
        params: <String, dynamic>{
          'p_business_id': businessId,
          'p_action': action.rpcValue,
          'p_reason': _nullable(reason),
        },
      );
      return AdminContentMutationResult.fromRpc(response);
    } on PostgrestException catch (error) {
      throw AdminContentRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<AdminContentMutationResult> deleteBusiness(String businessId) async {
    await _adminRepository.loadCurrentAdminProfile();
    try {
      final response = await _client.rpc(
        'admin_delete_business',
        params: <String, dynamic>{'p_business_id': businessId},
      );
      return AdminContentMutationResult.fromRpc(response);
    } on PostgrestException catch (error) {
      throw AdminContentRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<List<AdminAdvertisementItem>> loadAdvertisements() async {
    await _adminRepository.loadCurrentAdminProfile();

    final rows = _asRows(
      await _client
          .from('advertisements')
          .select(
            'id, business_id, title, image_path, target_url, placement, '
            'starts_at, ends_at, sort_order, is_active, created_at, '
            'updated_at, deleted_at, '
            'businesses!advertisements_business_id_fkey(id, name)',
          )
          .order('sort_order')
          .order('updated_at', ascending: false),
    );

    return rows.map(AdminAdvertisementItem.fromMap).toList(growable: false);
  }

  Future<List<AdminAdvertisementBusinessOption>>
      loadAdvertisementBusinesses() async {
    await _adminRepository.loadCurrentAdminProfile();

    final rows = _asRows(
      await _client
          .from('businesses')
          .select('id, name, deleted_at')
          .eq('status', 'approved')
          .eq('is_active', true)
          .order('name'),
    );

    return rows
        .where((row) => row['deleted_at'] == null)
        .map(AdminAdvertisementBusinessOption.fromMap)
        .where((business) => business.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<AdminContentMutationResult> saveAdvertisement(
    AdminAdvertisementDraft draft,
  ) async {
    await _adminRepository.loadCurrentAdminProfile();
    try {
      final response = await _client.rpc(
        'admin_upsert_advertisement',
        params: <String, dynamic>{
          'p_advertisement_id': draft.id,
          'p_business_id':
              draft.targetType == AdminAdvertisementTargetType.business
                  ? draft.businessId
                  : null,
          'p_title': draft.title.trim(),
          'p_image_path': draft.imagePath.trim(),
          'p_target_url':
              draft.targetType == AdminAdvertisementTargetType.external
                  ? _nullable(draft.targetUrl)
                  : null,
          'p_placement': draft.placement.rpcValue,
          'p_starts_at': draft.startsAt?.toUtc().toIso8601String(),
          'p_ends_at': draft.endsAt?.toUtc().toIso8601String(),
          'p_sort_order': draft.sortOrder,
        },
      );
      return AdminContentMutationResult.fromRpc(response);
    } on PostgrestException catch (error) {
      throw AdminContentRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<AdminContentMutationResult> setAdvertisementActive({
    required String advertisementId,
    required bool isActive,
  }) async {
    await _adminRepository.loadCurrentAdminProfile();
    try {
      final response = await _client.rpc(
        'admin_set_advertisement_active',
        params: <String, dynamic>{
          'p_advertisement_id': advertisementId,
          'p_is_active': isActive,
        },
      );
      return AdminContentMutationResult.fromRpc(response);
    } on PostgrestException catch (error) {
      throw AdminContentRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<AdminContentMutationResult> deleteAdvertisement(
    String advertisementId,
  ) async {
    await _adminRepository.loadCurrentAdminProfile();
    try {
      final response = await _client.rpc(
        'admin_delete_advertisement',
        params: <String, dynamic>{
          'p_advertisement_id': advertisementId,
        },
      );
      return AdminContentMutationResult.fromRpc(response);
    } on PostgrestException catch (error) {
      throw AdminContentRepositoryFailure(_friendlyMessage(error));
    }
  }

  String _friendlyMessage(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (error.code == '42501' || message.contains('administrator')) {
      return 'لا يملك الحساب صلاحية تنفيذ هذا الإجراء الإداري.';
    }
    if (error.code == '23505' || message.contains('already exists')) {
      return 'الاسم أو المعرّف مستخدم مسبقًا. اختر قيمة مختلفة.';
    }
    if (error.code == '23503' || message.contains('linked')) {
      return 'لا يمكن حذف العنصر لأنه مرتبط ببيانات أخرى.';
    }
    if (error.code == 'P0002' || message.contains('not found')) {
      return 'لم يعد العنصر المطلوب موجودًا.';
    }
    if (error.code == '22023' || message.contains('required')) {
      return 'تحقق من الحقول المطلوبة وصحة القيم المدخلة.';
    }
    return 'تعذر حفظ التغيير الإداري. تحقق من الاتصال ثم أعد المحاولة.';
  }

  List<Map<String, dynamic>> _asRows(Object? value) {
    if (value is! List) {
      throw const AdminContentRepositoryFailure(
        'أعاد Supabase بيانات غير متوقعة.',
      );
    }
    return value
        .whereType<Map>()
        .map(
          (row) => row.map(
            (key, item) => MapEntry(key.toString(), item),
          ),
        )
        .toList(growable: false);
  }

  String? _nullable(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class AdminContentRepositoryFailure implements Exception {
  const AdminContentRepositoryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
