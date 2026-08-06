import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/media_upload_service.dart';
import 'package:image/image.dart' as img;

void main() {
  test('ضغط صورة الإعلان الكامل يحافظ على الحد الأقصى والنسبة', () {
    final original = img.Image(width: 2400, height: 1350);
    final bytes = Uint8List.fromList(img.encodePng(original));

    final prepared = MediaImageProcessor.prepare(
      bytes,
      MediaAssetKind.advertisementExpanded,
    );

    expect(prepared.width, 1440);
    expect(prepared.height, 810);
    expect(prepared.bytes, isNotEmpty);
    expect(prepared.originalBytes, bytes.lengthInBytes);
  });

  test('مسارات الوسائط تفصل النشاط الموجود عن المسودة', () {
    final timestamp = DateTime.utc(2026, 8, 6, 15, 30);

    final existing = MediaUploadService.buildStoragePath(
      kind: MediaAssetKind.businessCover,
      entityId: '2fd94e37-9f51-4c79-8b93-8c3c73cb1bb5',
      userId: 'admin-user',
      timestamp: timestamp,
    );
    final draft = MediaUploadService.buildStoragePath(
      kind: MediaAssetKind.businessLogo,
      entityId: 'new',
      userId: 'admin-user',
      timestamp: timestamp,
    );

    expect(existing, startsWith('2fd94e37-9f51-4c79-8b93-8c3c73cb1bb5/'));
    expect(draft, startsWith('drafts/admin-user/'));
    expect(existing, endsWith('.jpg'));
    expect(draft, endsWith('.jpg'));
  });

  test('مسار الصورة الشخصية يبقى داخل مجلد المستخدم', () {
    final path = MediaUploadService.buildStoragePath(
      kind: MediaAssetKind.profileAvatar,
      entityId: 'ignored-profile-id',
      userId: 'user-123',
      timestamp: DateTime.utc(2026, 8, 6, 21),
    );

    expect(path, startsWith('user-123/avatar-'));
    expect(path, endsWith('.jpg'));
    expect(path, isNot(contains('drafts/')));
  });

  test('استخراج مسار التخزين لا يحذف رابطًا خارجيًا', () {
    const publicUrl = 'https://project.supabase.co/storage/v1/object/public/'
        'advertisements/admin/ad/expanded.jpg';

    expect(
      MediaUploadService.storagePathFromValue(
        publicUrl,
        bucket: 'advertisements',
      ),
      'admin/ad/expanded.jpg',
    );
    expect(
      MediaUploadService.storagePathFromValue(
        'https://cdn.example.com/banner.jpg',
        bucket: 'advertisements',
      ),
      isNull,
    );
  });
}
