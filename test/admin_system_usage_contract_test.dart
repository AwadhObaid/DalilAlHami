import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'system usage monitor remains admin-only and contains no embedded secrets',
      () {
    final dashboard =
        File('lib/features/admin/admin_dashboard_page.dart').readAsStringSync();
    final page = File('lib/features/admin/admin_system_usage_page.dart')
        .readAsStringSync();
    final repository = File(
      'lib/data/repositories/admin_system_usage_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/'
      '20260813134252_harden_admin_system_usage_snapshot.sql',
    ).readAsStringSync();

    expect(dashboard, contains('admin-system-usage-action'));
    expect(dashboard, contains('AdminSystemUsagePage'));
    expect(repository, contains("'admin_system_usage_snapshot'"));
    expect(
        migration, contains('if auth.uid() is null or not public.is_admin()'));
    expect(migration, contains('security invoker'));
    expect(migration, contains('pg_database_size(current_database())'));
    expect(migration, contains('storage.objects'));
    expect(migration, contains('pg_stat_user_tables'));

    final combined = '$page\n$repository';
    expect(combined, isNot(contains('service_role')));
    expect(combined, isNot(contains('SUPABASE_ACCESS_TOKEN')));
    expect(combined, isNot(contains('sb_secret_')));
  });
}
