import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../models/admin_system_usage.dart';
import 'admin_repository.dart';

class AdminSystemUsageRepository {
  AdminSystemUsageRepository({
    AdminRepository? adminRepository,
  }) : _adminRepository = adminRepository ?? AdminRepository();

  final AdminRepository _adminRepository;

  SupabaseClient get _client => SupabaseService.client;

  Future<AdminSystemUsageSnapshot> loadSnapshot() async {
    await _adminRepository.loadCurrentAdminProfile();

    try {
      final response = await _client.rpc('admin_system_usage_snapshot');
      final snapshot = AdminSystemUsageSnapshot.fromRpc(response);

      // storage.buckets metadata can be hidden even when the public Storage
      // objects themselves are readable. A dedicated admin RPC returns the
      // four application buckets without bypassing Storage RLS.
      final bucketResponse = await _client.rpc('admin_system_bucket_usage');
      final bucketUsage = AdminBucketUsage.readList(bucketResponse);

      return bucketUsage.isEmpty
          ? snapshot
          : snapshot.copyWith(bucketUsage: bucketUsage);
    } on PostgrestException catch (error) {
      throw AdminSystemUsageRepositoryFailure(_friendlyMessage(error));
    } on FormatException catch (error) {
      throw AdminSystemUsageRepositoryFailure(error.message);
    }
  }

  String _friendlyMessage(PostgrestException error) {
    if (error.code == '42501' ||
        error.message.contains('ADMIN_ACCESS_REQUIRED')) {
      return 'هذا الحساب لا يملك صلاحية قراءة مؤشرات النظام.';
    }

    return 'تعذر تحميل مؤشرات النظام من Supabase. '
        'تحقق من الاتصال ثم أعد المحاولة.';
  }
}

class AdminSystemUsageRepositoryFailure implements Exception {
  const AdminSystemUsageRepositoryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
