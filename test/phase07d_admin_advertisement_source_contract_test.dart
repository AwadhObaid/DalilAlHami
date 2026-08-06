import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('عقود Phase 07D متصلة بالإدارة والمزامنة المحلية', () {
    final dashboard = File(
      'lib/features/admin/admin_dashboard_page.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/data/repositories/admin_content_repository.dart',
    ).readAsStringSync();
    final management = File(
      'lib/features/admin/admin_advertisement_management_page.dart',
    ).readAsStringSync();
    final form = File(
      'lib/features/admin/admin_advertisement_form_page.dart',
    ).readAsStringSync();
    final localDatabase = File(
      'lib/data/local/database/local_directory_database.dart',
    ).readAsStringSync();
    final advertisementModel = File(
      'lib/models/directory_advertisement.dart',
    ).readAsStringSync();
    final dataStore = File(
      'lib/data/directory_data_store.dart',
    ).readAsStringSync();
    final home = File(
      'lib/features/home/home_dashboard_page.dart',
    ).readAsStringSync();
    final categories = File(
      'lib/features/directory/categories_overview_page.dart',
    ).readAsStringSync();
    final businessList = File(
      'lib/features/directory/category_list_page.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260806133000_admin_advertisement_management.sql',
    ).readAsStringSync();

    expect(dashboard, contains('admin-manage-advertisements-action'));
    expect(dashboard, contains('AdminAdvertisementManagementPage'));

    expect(repository, contains("'admin_upsert_advertisement'"));
    expect(repository, contains("'admin_set_advertisement_active'"));
    expect(repository, contains("'admin_delete_advertisement'"));

    expect(management, contains('admin-add-advertisement-button'));
    expect(management,
        contains('admin-advertisement-toggle-\${advertisement.id}'));
    expect(form, contains('admin-save-advertisement-button'));
    expect(form, contains('bottomNavigationBar: SafeArea'));

    expect(localDatabase, contains('static const int schemaVersion = 8'));
    expect(localDatabase, contains("advertisement.placement == 'home_top'"));
    expect(advertisementModel, contains('final String placement'));
    expect(advertisementModel, contains('final String? businessId'));
    expect(dataStore, contains('advertisementsForPlacement'));
    expect(home, contains("advertisementsForPlacement('home_middle')"));
    expect(categories, contains("advertisementsForPlacement('category')"));
    expect(
      businessList,
      contains("advertisementsForPlacement('business_list')"),
    );

    expect(migration, contains("'advertisement'"));
    expect(migration, contains('admin_upsert_advertisement'));
    expect(migration, contains('admin_set_advertisement_active'));
    expect(migration, contains('admin_delete_advertisement'));
    expect(migration, contains("'business_id', a.business_id"));
    expect(migration, contains("'placement', a.placement"));
    expect(migration, contains('public.is_admin()'));
  });
}
