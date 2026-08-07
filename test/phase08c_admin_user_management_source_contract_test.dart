import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 08C تربط الإدارة بالخادم وتحمي الأسرار والحسابات', () {
    final dashboard = File(
      'lib/features/admin/admin_dashboard_page.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/admin/admin_user_management_page.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/data/repositories/admin_user_repository.dart',
    ).readAsStringSync();
    final accountRepository = File(
      'lib/data/repositories/account_repository.dart',
    ).readAsStringSync();
    final accountHub = File(
      'lib/features/profile/account_hub_page.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260807030000_admin_user_management.sql',
    ).readAsStringSync();
    final edgeFunction = File(
      'supabase/functions/admin-users/index.ts',
    ).readAsStringSync();
    final deployScript = File(
      'scripts/deploy_phase_08c_supabase.ps1',
    ).readAsStringSync();
    final verifyScript = File(
      'scripts/verify_phase_08c_supabase.ps1',
    ).readAsStringSync();

    expect(dashboard, contains('admin-manage-users-action'));
    expect(dashboard, contains('AdminUserManagementPage'));
    expect(dashboard, isNot(contains('الوحدة الإدارية التالية')));
    expect(page, contains('admin-user-management-list'));
    expect(page, contains('admin-user-suspension-reason'));
    expect(page, contains('admin-user-delete-reason'));
    expect(page, contains('admin-user-suspension-reason-cancel'));
    expect(page, contains('admin-user-delete-reason-cancel'));
    expect(
        page, contains('class _AdminUserReasonDialog extends StatefulWidget'));
    expect(page, contains('_focusNode.dispose();'));
    expect(page, contains('_controller.dispose();'));
    expect(page, contains('scrollable: true'));
    expect(page, contains("errorText: _validationMessage"));
    expect(page,
        isNot(contains('final reasonController = TextEditingController();')));
    expect(page, contains('user.isCurrentUser || isActing ? null'));
    expect(page, contains('محذوف ظاهريًا'));

    expect(repository, contains("functions.invoke(\n        'admin-users'"));
    expect(repository,
        contains("'Authorization': 'Bearer \${session.accessToken}'"));
    expect(repository, contains('jsonDecode(details)'));
    expect(repository, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));

    expect(edgeFunction, contains("Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')"));
    expect(edgeFunction, contains('service.auth.getUser(token)'));
    expect(edgeFunction, contains('previousBanDuration(authBefore)'));
    expect(edgeFunction, contains('errorMessage(error)'));
    expect(edgeFunction, contains(r'[^\p{L}\p{N}@\s]'));
    expect(edgeFunction, contains('service.auth.admin.updateUserById'));
    expect(edgeFunction, contains("ban_duration: desiredBan"));
    expect(edgeFunction, contains("action === 'set_deleted'"));
    expect(edgeFunction,
        contains("p_action: isDeleted ? 'soft_delete' : 'restore'"));
    expect(edgeFunction, contains("service.rpc('admin_apply_user_change'"));
    expect(edgeFunction, contains("userId === caller.id"));
    expect(deployScript, isNot(contains('--no-verify-jwt')));
    expect(verifyScript, contains('return [pscustomobject]@{'));
    expect(verifyScript, contains('Output = [string]\$combined'));
    expect(verifyScript, contains('Write-Host \$line'));
    expect(verifyScript, contains('confirmedMigrationRow'));
    expect(verifyScript, contains('LOCAL/REMOTE row'));
    expect(
        verifyScript, isNot(contains('return @(\$combined, \$combinedPath)')));
    expect(verifyScript, isNot(contains('\$migrationResult[0]')));

    expect(migration, contains('from auth.users auth_user'));
    expect(migration, contains('create or replace function public.is_admin()'));
    expect(migration,
        contains('create table if not exists public.admin_user_actions'));
    expect(migration, contains("p_actor_id = p_target_user_id"));
    expect(migration, contains('v_active_admin_count <= 1'));
    expect(migration, contains('and profile.deleted_at is null'));
    expect(migration, contains("'soft_deleted', 'restored'"));
    expect(migration,
        contains('create policy storage_active_account_access_guard'));
    expect(migration, contains('enforce_active_account_mutation'));
    expect(migration,
        contains('The last active administrator cannot be changed.'));
    expect(migration,
        contains('grant execute on function public.admin_apply_user_change'));
    expect(migration, contains('to service_role'));
    expect(migration,
        contains('revoke all on function public.admin_apply_user_change'));

    expect(
        accountRepository, contains('throw AccountSuspendedFailure(profile)'));
    expect(accountRepository, contains('on AccountSuspendedFailure'));
    expect(accountHub, contains('account-suspended-banner'));
    expect(accountHub, contains('accountSuspended ? null : _openProfile'));
    expect(accountRepository, contains('_ensureCachedAccountActive'));
  });
}
