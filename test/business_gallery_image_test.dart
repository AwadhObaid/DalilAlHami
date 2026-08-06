import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/business.dart';
import 'package:hami_guide/models/business_gallery_image.dart';

void main() {
  test('يرتب معرض النشاط ويستبعد الصور المحذوفة', () {
    final images = BusinessGalleryImage.readList([
      {
        'id': 'second',
        'business_id': 'business-1',
        'storage_path': 'business-1/gallery-second.jpg',
        'sort_order': 2,
        'is_primary': false,
      },
      {
        'id': 'primary',
        'business_id': 'business-1',
        'storage_path': 'business-1/gallery-primary.jpg',
        'public_url': 'https://example.com/primary.jpg',
        'sort_order': 4,
        'is_primary': true,
      },
      {
        'id': 'deleted',
        'business_id': 'business-1',
        'storage_path': 'business-1/deleted.jpg',
        'sort_order': 0,
        'is_primary': false,
        'deleted_at': '2026-08-06T20:00:00Z',
      },
    ]);

    expect(images.map((image) => image.id), ['primary', 'second']);
    expect(images.first.displayUrl, 'https://example.com/primary.jpg');
  });

  test('يستخدم الغلاف ثم صورة المعرض الرئيسية ثم الشعار', () {
    const gallery = BusinessGalleryImage(
      id: 'gallery-1',
      businessId: 'business-1',
      storagePath: 'business-1/gallery.jpg',
      publicUrl: 'https://example.com/gallery.jpg',
      sortOrder: 0,
      isPrimary: true,
    );

    const withGallery = Business(
      id: 'business-1',
      name: 'نشاط بالمعرض',
      phone: '777000111',
      category: 'خدمات',
      place: 'الحامي',
      galleryImages: [gallery],
    );
    expect(withGallery.preferredImageUrl, 'https://example.com/gallery.jpg');

    final withCover = withGallery.copyWith(
      coverUrl: 'https://example.com/cover.jpg',
    );
    expect(withCover.preferredImageUrl, 'https://example.com/cover.jpg');
  });
}
