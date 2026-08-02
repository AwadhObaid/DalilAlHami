import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

abstract final class SupabaseService {
  static bool _initialized = false;

  static bool get isConfigured => SupabaseConfig.isConfigured;

  static bool get isInitialized => _initialized;

  static Future<void> initializeIfConfigured() async {
    if (_initialized || !isConfigured) {
      return;
    }

    await Supabase.initialize(
      url: SupabaseConfig.url.trim(),
      publishableKey: SupabaseConfig.publishableKey.trim(),
    );

    _initialized = true;
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'لم تتم تهيئة Supabase. شغّل التطبيق باستخدام '
        'SUPABASE_URL وSUPABASE_PUBLISHABLE_KEY.',
      );
    }

    return Supabase.instance.client;
  }
}
