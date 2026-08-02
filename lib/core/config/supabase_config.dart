abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured {
    final normalizedUrl = url.trim();
    final normalizedKey = publishableKey.trim();

    if (normalizedUrl.isEmpty || normalizedKey.isEmpty) {
      return false;
    }

    final parsedUrl = Uri.tryParse(normalizedUrl);
    return parsedUrl != null &&
        parsedUrl.hasScheme &&
        parsedUrl.host.endsWith('.supabase.co');
  }
}
