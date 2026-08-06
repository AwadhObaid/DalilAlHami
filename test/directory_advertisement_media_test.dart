import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/directory_advertisement.dart';

void main() {
  test('الإعلان يقرأ صورتي العرض الكامل والمصغر من المزامنة', () {
    final advertisement = DirectoryAdvertisement.fromSupabase(
      const <String, dynamic>{
        'id': 'ad-media',
        'title': 'إعلان الصور',
        'sort_order': 1,
        'image_path': 'admin/ad/expanded.jpg',
        'compact_image_path': 'admin/ad/compact.jpg',
        'placement': 'home_top',
        'is_active': true,
      },
    );

    expect(advertisement.imagePath, 'admin/ad/expanded.jpg');
    expect(advertisement.compactImagePath, 'admin/ad/compact.jpg');
  });
}
