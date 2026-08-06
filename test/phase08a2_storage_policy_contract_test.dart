import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('سياسات التخزين تطابق مسارات النشاط والصورة الشخصية', () {
    final migration = File(
      'supabase/migrations/'
      '20260806230000_business_media_storage_ownership_fix.sql',
    ).readAsStringSync();
    final mediaService = File(
      'lib/core/services/media_upload_service.dart',
    ).readAsStringSync();

    expect(
      migration,
      contains('can_manage_business_storage_path'),
    );
    expect(
      migration,
      contains(
        'business.id::text = (storage.foldername(p_name))[1]',
      ),
    );
    expect(
      migration,
      contains('storage_business_media_owner_final_insert'),
    );
    expect(
      migration,
      contains('storage_business_media_owner_final_update'),
    );
    expect(
      migration,
      contains('storage_business_media_owner_final_delete'),
    );
    expect(
      migration,
      contains('public.can_manage_business_storage_path(name)'),
    );
    expect(
      migration,
      contains('storage_avatar_owner_insert'),
    );
    expect(
      migration,
      contains('storage_avatar_owner_update'),
    );
    expect(
      migration,
      contains('storage_avatar_owner_delete'),
    );
    expect(
      migration,
      contains(
        "(storage.foldername(name))[1] = (select auth.uid())::text",
      ),
    );
    expect(
      migration,
      contains('storage_avatar_admin_delete_all'),
    );

    expect(
      mediaService,
      contains(
        r"return '$safeEntity/${kind.fileStem}-$stamp.jpg';",
      ),
    );
    expect(
      mediaService,
      contains(
        r"return '$safeUser/${kind.fileStem}-$stamp.jpg';",
      ),
    );
  });
}
