import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../models/admin_media_overview.dart';
import 'admin_repository.dart';

class AdminMediaRepository {
  AdminMediaRepository({
    AdminRepository? adminRepository,
  }) : _adminRepository = adminRepository ?? AdminRepository();

  final AdminRepository _adminRepository;

  SupabaseClient get _client => SupabaseService.client;

  Future<AdminMediaOverview> loadOverview() async {
    await _adminRepository.loadCurrentAdminProfile();
    try {
      final response = await _client.rpc('admin_get_media_overview');
      return AdminMediaOverview.fromRpc(response);
    } on PostgrestException catch (error) {
      throw AdminMediaRepositoryFailure(_friendlyMessage(error));
    } on FormatException catch (error) {
      throw AdminMediaRepositoryFailure(error.message);
    }
  }

  Future<List<AdminMediaCleanupCandidate>> loadCleanupCandidates() async {
    await _adminRepository.loadCurrentAdminProfile();
    try {
      final response = await _client.rpc('admin_media_cleanup_candidates');
      return AdminMediaCleanupCandidate.readList(response);
    } on PostgrestException catch (error) {
      throw AdminMediaRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<AdminMediaCleanupResult> cleanupCandidates(
    List<AdminMediaCleanupCandidate> candidates,
  ) async {
    await _adminRepository.loadCurrentAdminProfile();

    // Re-scan immediately before deletion. A file that became referenced after
    // the administrator opened the confirmation dialog must never be removed.
    final currentCandidates = await loadCleanupCandidates();
    final currentKeys = <String>{
      for (final candidate in currentCandidates)
        '${candidate.bucketId}/${candidate.storagePath}',
    };
    final unique = <String, AdminMediaCleanupCandidate>{};
    for (final candidate in candidates) {
      final key = '${candidate.bucketId}/${candidate.storagePath}';
      if (currentKeys.contains(key)) {
        unique[key] = candidate;
      }
    }

    var deleted = 0;
    final failed = <AdminMediaCleanupCandidate>[];
    final grouped = <String, List<AdminMediaCleanupCandidate>>{};
    for (final candidate in unique.values) {
      grouped.putIfAbsent(candidate.bucketId, () => []).add(candidate);
    }

    for (final entry in grouped.entries) {
      final paths = entry.value.map((item) => item.storagePath).toList();
      try {
        await _client.storage.from(entry.key).remove(paths);
        deleted += paths.length;
      } on StorageException {
        failed.addAll(entry.value);
      } catch (_) {
        failed.addAll(entry.value);
      }
    }

    return AdminMediaCleanupResult(
      deletedCount: deleted,
      failed: List<AdminMediaCleanupCandidate>.unmodifiable(failed),
    );
  }

  String _friendlyMessage(PostgrestException error) {
    if (error.code == '42501') {
      return 'لا تملك صلاحية إدارة الوسائط.';
    }
    return 'تعذر تحميل بيانات الوسائط. تحقق من الاتصال ثم أعد المحاولة.';
  }
}

class AdminMediaCleanupResult {
  const AdminMediaCleanupResult({
    required this.deletedCount,
    required this.failed,
  });

  final int deletedCount;
  final List<AdminMediaCleanupCandidate> failed;

  bool get isComplete => failed.isEmpty;
}

class AdminMediaRepositoryFailure implements Exception {
  const AdminMediaRepositoryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
