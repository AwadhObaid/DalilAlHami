import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 08A-1 تربط الرفع والتخزين والعرض المؤقت', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final service = File(
      'lib/core/services/media_upload_service.dart',
    ).readAsStringSync();
    final field = File(
      'lib/features/shared/widgets/admin_media_field.dart',
    ).readAsStringSync();
    final cachedImage = File(
      'lib/features/shared/widgets/cached_directory_image.dart',
    ).readAsStringSync();
    final categoryForm = File(
      'lib/features/admin/admin_category_form_page.dart',
    ).readAsStringSync();
    final businessForm = File(
      'lib/features/admin/admin_business_form_page.dart',
    ).readAsStringSync();
    final advertisementForm = File(
      'lib/features/admin/admin_advertisement_form_page.dart',
    ).readAsStringSync();
    final slider = File(
      'lib/features/home/widgets/ad_slider.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260806170000_media_foundation_primary_images.sql',
    ).readAsStringSync();
    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();

    expect(pubspec, contains('image: 4.8.0'));
    expect(pubspec, isNot(contains('image: ^4.8.0')));
    expect(pubspec, contains('flutter_local_notifications: ^19.5.0'));
    expect(pubspec, contains('cached_network_image: ^3.4.1'));
    expect(service, contains('uploadBinary'));
    expect(service, contains('MediaImageProcessor'));
    expect(service, isNot(contains("import 'dart:typed_data';")));
    expect(service, contains("cacheControl: '31536000'"));
    expect(field, contains('LinearProgressIndicator'));
    expect(cachedImage, contains('CachedNetworkImage'));
    expect(categoryForm, contains('MediaAssetKind.category'));
    expect(businessForm, contains('MediaAssetKind.businessLogo'));
    expect(businessForm, contains('MediaAssetKind.businessCover'));
    expect(
      advertisementForm,
      contains('MediaAssetKind.advertisementExpanded'),
    );
    expect(
      advertisementForm,
      contains('MediaAssetKind.advertisementCompact'),
    );
    expect(slider, contains('compactImagePaths'));
    expect(slider, contains("bucket: 'advertisements'"));
    expect(migration, contains("'category-media'"));
    expect(migration, contains('compact_image_path'));
    expect(migration, contains('storage_public_read_directory_media'));
    expect(iosInfo, contains('NSPhotoLibraryUsageDescription'));
  });
}
