import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('عقود Phase 07C موجودة ومتصلة بلوحة الإدارة', () {
    final dashboard = File(
      'lib/features/admin/admin_dashboard_page.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/data/repositories/admin_content_repository.dart',
    ).readAsStringSync();
    final businessForm = File(
      'lib/features/admin/admin_business_form_page.dart',
    ).readAsStringSync();
    final businessManagement = File(
      'lib/features/admin/admin_business_management_page.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260806003000_admin_content_management.sql',
    ).readAsStringSync();

    expect(dashboard, contains('admin-manage-businesses-action'));
    expect(dashboard, contains('admin-manage-categories-action'));
    expect(dashboard, contains('AdminBusinessManagementPage'));
    expect(dashboard, contains('AdminCategoryManagementPage'));

    expect(repository, contains("'admin_upsert_category'"));
    expect(repository, contains("'admin_set_category_active'"));
    expect(repository, contains("'admin_upsert_business'"));
    expect(repository, contains("'admin_manage_business'"));
    expect(repository, contains("'admin_delete_business'"));

    expect(businessForm, contains('bottomNavigationBar: SafeArea'));
    expect(businessForm, contains('admin-save-business-button'));
    expect(
      businessManagement,
      contains('FloatingActionButtonLocation.startFloat'),
    );
    expect(businessManagement, contains('business-actions-\${business.id}'));
    expect(
      businessManagement,
      contains('business-menu-suspend-\${business.id}'),
    );
    expect(
      businessManagement,
      contains('admin-business-suspension-confirm'),
    );
    expect(
      businessManagement,
      contains('await onAction(AdminBusinessManagementAction.suspend)'),
    );

    expect(migration,
        contains('create table if not exists public.admin_content_actions'));
    expect(migration, contains('public.is_admin()'));
    expect(migration, contains('admin_record_content_action'));
    expect(migration, contains('admin_delete_category'));
    expect(migration, contains('admin_delete_business'));
  });
}
