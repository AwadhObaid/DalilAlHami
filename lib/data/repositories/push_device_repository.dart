import '../../core/services/supabase_service.dart';

class PushDeviceRepository {
  const PushDeviceRepository();

  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentUser == null) {
      return;
    }

    final safeToken = token.trim();
    if (safeToken.isEmpty) {
      return;
    }

    await SupabaseService.client.rpc(
      'register_push_device',
      params: <String, dynamic>{
        'p_fcm_token': safeToken,
        'p_platform': platform,
      },
    );
  }

  Future<void> unregisterToken(String token) async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentUser == null) {
      return;
    }

    final safeToken = token.trim();
    if (safeToken.isEmpty) {
      return;
    }

    await SupabaseService.client.rpc(
      'unregister_push_device',
      params: <String, dynamic>{'p_fcm_token': safeToken},
    );
  }
}
