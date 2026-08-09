import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 08A-2 تربط معرض الأنشطة والتنظيف والمزامنة', () {
    final model = File(
      'lib/models/business_gallery_image.dart',
    ).readAsStringSync();
    final manager = File(
      'lib/features/shared/widgets/business_gallery_manager.dart',
    ).readAsStringSync();
    final details = File(
      'lib/features/directory/member_details_page.dart',
    ).readAsStringSync();
    final database = File(
      'lib/data/local/database/local_directory_database.dart',
    ).readAsStringSync();
    final syncGateway = File(
      'lib/data/sync_queue/supabase_sync_queue_gateway.dart',
    ).readAsStringSync();
    final adminDashboard = File(
      'lib/features/admin/admin_dashboard_page.dart',
    ).readAsStringSync();
    final profilePage = File(
      'lib/features/profile/profile_page.dart',
    ).readAsStringSync();
    final accountProfilePage = File(
      'lib/features/profile/account_profile_page.dart',
    ).readAsStringSync();
    final accountRepository = File(
      'lib/data/repositories/account_repository.dart',
    ).readAsStringSync();
    final mediaService = File(
      'lib/core/services/media_upload_service.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260806210000_business_gallery_advanced_media.sql',
    ).readAsStringSync();

    expect(model, contains('class BusinessGalleryImage'));
    expect(manager, contains('business-gallery-reorder-list'));
    expect(manager, contains('استبدال الصورة'));
    expect(details, contains('BusinessGallerySection'));
    final schemaMatch = RegExp(
      r'static const int schemaVersion\s*=\s*(\d+);',
    ).firstMatch(database);
    expect(schemaMatch, isNotNull);
    final schemaVersion = int.parse(schemaMatch!.group(1)!);
    expect(schemaVersion, greaterThanOrEqualTo(9));
    expect(database, contains('local_gallery_json'));
    expect(syncGateway, contains('localGalleryPathsKey'));
    expect(syncGateway, contains('finalize_owner_business_media'));
    expect(adminDashboard, contains('admin-manage-media-action'));
    expect(accountProfilePage, contains('account-profile-page'));
    expect(accountProfilePage, contains('_deleteAvatarBestEffort'));
    expect(accountProfilePage, contains('MediaUploadResult? upload'));
    expect(profilePage, contains('EmptyOwnedBusinessState'));
    expect(accountRepository, contains('updateProfileAvatar'));
    expect(mediaService, contains('MediaAssetKind.profileAvatar'));
    expect(migration, contains("'profile_avatars'"));
    expect(migration, contains("when 'avatars' then"));
    expect(migration,
        contains('drop policy if exists business_images_owner_insert'));
    expect(migration, contains('manage_business_gallery'));
    expect(migration, contains('admin_media_cleanup_candidates'));
    expect(migration, contains("v_action = 'replace'"));
    expect(
      migration,
      isNot(contains('grant execute on function public.business_gallery_json')),
    );
  });
}
