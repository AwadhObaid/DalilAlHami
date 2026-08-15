import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../models/account_profile.dart';
import '../../models/admin_business_review.dart';
import '../../models/admin_dashboard_snapshot.dart';

class AdminRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<AccountProfile> loadCurrentAdminProfile() async {
    if (!SupabaseService.isInitialized) {
      throw const AdminRepositoryFailure(
        'تحتاج لوحة الإدارة إلى اتصال Supabase صالح.',
      );
    }

    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw const AdminAccessDenied('يجب تسجيل الدخول أولًا.');
    }

    final rows = await _client
        .from('profiles')
        .select('id, full_name, email, phone, avatar_url, role, is_active')
        .eq('id', user.id)
        .limit(1);

    if (rows.isEmpty) {
      throw const AdminAccessDenied('تعذر التحقق من صلاحية الحساب.');
    }

    final profile = AccountProfile.fromMap(rows.first);
    if (!profile.isActive) {
      throw const AdminAccessDenied('هذا الحساب موقوف عن استخدام الإدارة.');
    }
    if (!profile.isAdmin) {
      throw const AdminAccessDenied('هذا الحساب لا يملك صلاحية الإدارة.');
    }

    return profile;
  }

  Future<AdminDashboardSnapshot> loadDashboard() async {
    _requireSupabase();

    final profiles = _asRows(
      await _client.from('profiles').select('id, is_active'),
    );
    final categories = _asRows(
      await _client.from('categories').select('id, is_active'),
    );
    final businesses = _asRows(
      await _client.from('businesses').select('id, status, is_active'),
    );
    final advertisements = _asRows(
      await _client.from('advertisements').select(
            'id, is_active, starts_at, ends_at',
          ),
    );
    final now = DateTime.now().toUtc();

    int businessCount(String status) {
      return businesses
          .where((row) => row['status']?.toString() == status)
          .length;
    }

    return AdminDashboardSnapshot(
      totalUsers: profiles.length,
      activeUsers: profiles.where((row) => row['is_active'] != false).length,
      totalCategories: categories.length,
      activeCategories:
          categories.where((row) => row['is_active'] != false).length,
      totalBusinesses: businesses.length,
      pendingBusinesses: businessCount('pending'),
      approvedBusinesses: businessCount('approved'),
      rejectedBusinesses: businessCount('rejected'),
      changesRequestedBusinesses: businessCount('changes_requested'),
      draftBusinesses: businessCount('draft'),
      suspendedBusinesses: businessCount('suspended'),
      totalAdvertisements: advertisements.length,
      activeAdvertisements: advertisements.where((row) {
        if (row['is_active'] == false) {
          return false;
        }

        final startsAt = _parseUtc(row['starts_at']);
        final endsAt = _parseUtc(row['ends_at']);
        final started = startsAt == null || !startsAt.isAfter(now);
        final notEnded = endsAt == null || endsAt.isAfter(now);
        return started && notEnded;
      }).length,
      loadedAt: now,
    );
  }

  Future<List<AdminBusinessReviewItem>> loadPendingBusinesses() async {
    await loadCurrentAdminProfile();

    final businesses = _asRows(
      await _client
          .from('businesses')
          .select(
            'id, owner_id, category_id, name, description, phone, whatsapp, '
            'address, latitude, longitude, logo_url, cover_url, status, '
            'rejection_reason, is_featured, is_active, created_at, updated_at, '
            'categories!businesses_category_id_fkey(id, name_ar, slug), '
            'business_contact_numbers(id, business_id, phone_number, label, '
            'is_primary, supports_whatsapp, sort_order, created_at, updated_at, '
            'deleted_at, sync_version)',
          )
          .eq('status', 'pending')
          .order('created_at', ascending: true),
    );

    if (businesses.isEmpty) {
      return const <AdminBusinessReviewItem>[];
    }

    final profiles = _profileMap(
      _asRows(
        await _client
            .from('profiles')
            .select('id, full_name, email, is_active'),
      ),
    );

    return businesses.map((row) {
      final ownerId = row['owner_id']?.toString() ?? '';
      final owner = profiles[ownerId];
      return AdminBusinessReviewItem.fromMap(
        row,
        ownerName: owner?['full_name']?.toString(),
        ownerEmail: owner?['email']?.toString(),
      );
    }).toList(growable: false);
  }

  Future<AdminBusinessReviewItem> loadBusinessForReview(
    String businessId,
  ) async {
    await loadCurrentAdminProfile();

    final business = await _client
        .from('businesses')
        .select(
          'id, owner_id, category_id, name, description, phone, whatsapp, '
          'address, latitude, longitude, logo_url, cover_url, status, '
          'rejection_reason, is_featured, is_active, created_at, updated_at, '
          'categories!businesses_category_id_fkey(id, name_ar, slug), '
          'business_contact_numbers(id, business_id, phone_number, label, '
          'is_primary, supports_whatsapp, sort_order, created_at, updated_at, '
          'deleted_at, sync_version)',
        )
        .eq('id', businessId)
        .single();

    final ownerId = business['owner_id']?.toString() ?? '';
    Map<String, dynamic>? owner;
    if (ownerId.isNotEmpty) {
      final ownerRows = _asRows(
        await _client
            .from('profiles')
            .select('id, full_name, email, phone, is_active')
            .eq('id', ownerId)
            .limit(1),
      );
      if (ownerRows.isNotEmpty) {
        owner = ownerRows.first;
      }
    }

    final imageRows = _asRows(
      await _client
          .from('business_images')
          .select('id, storage_path, alt_text, sort_order, created_at')
          .eq('business_id', businessId)
          .order('sort_order'),
    );
    final images = imageRows
        .map(
          (row) => AdminBusinessImage.fromMap(
            row,
            publicUrlBuilder: (path) =>
                _client.storage.from('business-media').getPublicUrl(path),
          ),
        )
        .toList(growable: false);

    final historyRows = _asRows(
      await _client
          .from('business_reviews')
          .select(
            'id, reviewer_id, action, reason, previous_status, '
            'resulting_status, created_at',
          )
          .eq('business_id', businessId)
          .order('created_at', ascending: false),
    );

    final reviewerProfiles = _profileMap(
      _asRows(
        await _client.from('profiles').select('id, full_name, email'),
      ),
    );
    final history = historyRows.map((row) {
      final reviewerId = row['reviewer_id']?.toString() ?? '';
      final reviewer = reviewerProfiles[reviewerId];
      return AdminBusinessReviewHistory.fromMap(
        row,
        reviewerName: reviewer?['full_name']?.toString(),
      );
    }).toList(growable: false);

    return AdminBusinessReviewItem.fromMap(
      Map<String, dynamic>.from(business),
      ownerName: owner?['full_name']?.toString(),
      ownerEmail: owner?['email']?.toString(),
      images: images,
      history: history,
    );
  }

  Future<AdminBusinessReviewResult> reviewBusiness({
    required String businessId,
    required AdminReviewDecision decision,
    String? reason,
  }) async {
    await loadCurrentAdminProfile();

    final normalizedReason = reason?.trim();
    if (decision.requiresReason &&
        (normalizedReason == null || normalizedReason.length < 5)) {
      throw const AdminRepositoryFailure(
        'اكتب سببًا واضحًا لا يقل عن خمسة أحرف.',
      );
    }

    Object? response;
    try {
      response = await _client.rpc(
        'admin_review_business',
        params: <String, dynamic>{
          'p_business_id': businessId,
          'p_decision': decision.rpcValue,
          'p_reason': normalizedReason,
        },
      );
    } on PostgrestException catch (error) {
      throw AdminRepositoryFailure(_friendlyPostgrestMessage(error));
    }

    return AdminBusinessReviewResult.fromRpc(response);
  }

  void _requireSupabase() {
    if (!SupabaseService.isInitialized) {
      throw const AdminRepositoryFailure(
        'تحتاج لوحة الإدارة إلى اتصال Supabase صالح.',
      );
    }
  }

  String _friendlyPostgrestMessage(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (error.code == '42501' || message.contains('administrator')) {
      return 'لا يملك الحساب صلاحية تنفيذ قرار المراجعة.';
    }
    if (error.code == 'P0002' || message.contains('not found')) {
      return 'لم يعد النشاط المطلوب موجودًا.';
    }
    if (error.code == '22023' || message.contains('pending')) {
      return 'لا يمكن مراجعة هذا النشاط لأنه لم يعد قيد المراجعة.';
    }
    return 'تعذر حفظ قرار المراجعة. أعد المحاولة بعد التحقق من الاتصال.';
  }

  Map<String, Map<String, dynamic>> _profileMap(
    List<Map<String, dynamic>> rows,
  ) {
    return <String, Map<String, dynamic>>{
      for (final row in rows)
        if ((row['id']?.toString() ?? '').isNotEmpty) row['id'].toString(): row,
    };
  }

  List<Map<String, dynamic>> _asRows(Object? value) {
    if (value is! List) {
      throw const AdminRepositoryFailure(
        'أعاد Supabase بيانات غير متوقعة للوحة الإدارة.',
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

  DateTime? _parseUtc(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return DateTime.tryParse(text)?.toUtc();
  }
}

class AdminAccessDenied implements Exception {
  const AdminAccessDenied(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminRepositoryFailure implements Exception {
  const AdminRepositoryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
