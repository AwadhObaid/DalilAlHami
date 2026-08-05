import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('مراجعة الأنشطة محمية بدالة RPC وتحتفظ بسجل تدقيق', () {
    final migration = File(
      'supabase/migrations/'
      '20260805234500_admin_business_review_workflow.sql',
    ).readAsStringSync();
    final repository = File(
      'lib/data/repositories/admin_repository.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/features/admin/admin_dashboard_page.dart',
    ).readAsStringSync();
    final deployScript = File(
      'scripts/deploy_phase_07b_supabase.ps1',
    ).readAsStringSync();

    expect(migration,
        contains('create table if not exists public.business_reviews'));
    expect(migration,
        contains('create or replace function public.admin_review_business'));
    expect(migration, contains("'changes_requested'"));
    expect(migration, contains('if not public.is_admin()'));
    expect(migration, contains('for update;'));
    expect(repository, contains(".rpc(\n        'admin_review_business'"));
    expect(repository, contains('loadCurrentAdminProfile'));
    expect(dashboard, contains('AdminBusinessReviewPage'));
    expect(dashboard, contains('onTap: _openBusinessReviews'));
    expect(deployScript, contains('Push-Location \$resolvedRoot'));
    expect(deployScript, contains('Pop-Location'));
    expect(deployScript, contains('db push --linked'));
  });
}
