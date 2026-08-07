import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class GoogleAuthService {
  const GoogleAuthService();

  static const String redirectUrl =
      'com.awadhobaid.dalilalhami://login-callback/';

  Future<bool> signIn() async {
    if (!SupabaseService.isInitialized) {
      throw const GoogleAuthFailure(
        'إعداد Supabase غير متاح في هذا التشغيل.',
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
        'تعذر فتح تسجيل Google. تحقق من الإنترنت وحاول مرة أخرى.\n$error',
      );
    }
  }

  String _messageForAuthError(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('provider') &&
        (message.contains('disabled') || message.contains('not enabled'))) {
      return 'تسجيل Google غير مفعّل في إعدادات Supabase.';
    }

    if (message.contains('redirect') || message.contains('callback')) {
      return 'رابط الرجوع من Google غير مضبوط في Supabase.';
    }

    if (message.contains('network') || message.contains('socket')) {
      return 'تعذر الاتصال بخدمة تسجيل الدخول.';
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
