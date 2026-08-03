import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class GoogleAuthService {
  const GoogleAuthService();

  static const String redirectUrl =
      'com.awadhobaid.dalilalhami://login-callback/';

  Future<bool> signIn() async {
    if (!SupabaseService.isInitialized) {
      throw const GoogleAuthFailure(
        'ط¥ط¹ط¯ط§ط¯ Supabase ط؛ظٹط± ظ…طھط§ط­ ظپظٹ ظ‡ط°ط§ ط§ظ„طھط´ط؛ظٹظ„.',
      );
    }

    try {
      return await SupabaseService.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: const <String, String>{
          'prompt': 'select_account',
        },
      );
    } on AuthException catch (error) {
      throw GoogleAuthFailure(_messageForAuthError(error));
    } catch (error) {
      throw GoogleAuthFailure(
        'طھط¹ط°ط± ظپطھط­ طھط³ط¬ظٹظ„ Google. طھط­ظ‚ظ‚ ظ…ظ† ط§ظ„ط¥ظ†طھط±ظ†طھ ظˆط­ط§ظˆظ„ ظ…ط±ط© ط£ط®ط±ظ‰.\n$error',
      );
    }
  }

  String _messageForAuthError(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('provider') &&
        (message.contains('disabled') || message.contains('not enabled'))) {
      return 'طھط³ط¬ظٹظ„ Google ط؛ظٹط± ظ…ظپط¹ظ‘ظ„ ظپظٹ ط¥ط¹ط¯ط§ط¯ط§طھ Supabase.';
    }

    if (message.contains('redirect') || message.contains('callback')) {
      return 'ط±ط§ط¨ط· ط§ظ„ط±ط¬ظˆط¹ ظ…ظ† Google ط؛ظٹط± ظ…ط¶ط¨ظˆط· ظپظٹ Supabase.';
    }

    if (message.contains('network') || message.contains('socket')) {
      return 'طھط¹ط°ط± ط§ظ„ط§طھطµط§ظ„ ط¨ط®ط¯ظ…ط© طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„.';
    }

    return error.message;
  }
}

class GoogleAuthFailure implements Exception {
  const GoogleAuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
