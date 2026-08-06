import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 08B تربط الخرائط والموقع والمزامنة والصلاحيات', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final business = File('lib/models/business.dart').readAsStringSync();
    final account = File(
      'lib/data/repositories/account_repository.dart',
    ).readAsStringSync();
    final database = File(
      'lib/data/local/database/local_directory_database.dart',
    ).readAsStringSync();
    final gateway = File(
      'lib/data/sync_queue/supabase_sync_queue_gateway.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/features/profile/profile_page.dart',
    ).readAsStringSync();
    final adminForm = File(
      'lib/features/admin/admin_business_form_page.dart',
    ).readAsStringSync();
    final details = File(
      'lib/features/directory/member_details_page.dart',
    ).readAsStringSync();
    final picker = File(
      'lib/features/shared/pages/business_location_picker_page.dart',
    ).readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    final androidScript = File(
      'scripts/configure_phase_08b_android_location.ps1',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260807010000_maps_location_foundation.sql',
    ).readAsStringSync();

    expect(pubspec, contains('flutter_map: ^8.3.1'));
    expect(pubspec, contains('geolocator: ^14.0.3'));
    expect(pubspec, contains('latlong2: ^0.10.1'));
    expect(business, contains('BusinessLocation? get location'));
    expect(account, contains("'latitude': latitude"));
    expect(account, contains("'longitude': longitude"));
    expect(database, contains('schemaVersion = 10'));
    expect(database, contains('latitude REAL'));
    expect(database, contains('longitude REAL'));
    expect(gateway, contains('owner_set_business_location'));
    expect(profile, contains('BusinessLocationPicker'));
    expect(adminForm, contains('BusinessLocationPicker'));
    expect(adminForm, isNot(contains('admin-business-latitude-field')));
    expect(details, contains('BusinessLocationSection'));
    expect(picker, contains('OpenStreetMap contributors'));
    expect(picker, contains('userAgentPackageName'));
    expect(ios, contains('NSLocationWhenInUseUsageDescription'));
    expect(androidScript, contains('ACCESS_COARSE_LOCATION'));
    expect(androidScript, contains('ACCESS_FINE_LOCATION'));
    expect(migration, contains('owner_set_business_location'));
    expect(migration, contains("'latitude', b.latitude"));
    expect(migration, contains("'longitude', b.longitude"));
    expect(migration, contains("'sync_version', coalesce(v_sync_version, 0)"));
    expect(migration, contains('business.owner_id = v_user_id'));
  });
}
