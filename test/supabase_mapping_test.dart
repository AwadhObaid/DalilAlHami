import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/business.dart';
import 'package:hami_guide/models/directory_advertisement.dart';
import 'package:hami_guide/models/service_category.dart';

void main() {
  group('Supabase model mapping', () {
    test('maps a service category with sync metadata', () {
      final category = ServiceCategory.fromSupabase({
        'id': 'category-id',
        'name_ar': 'مطاعم',
        'slug': 'restaurants',
        'icon_name': 'restaurant',
        'sort_order': 40,
        'display_group': 'services',
        'updated_at': '2026-08-03T20:00:00Z',
        'sync_version': 15,
      });

      expect(category.id, 'category-id');
      expect(category.name, 'مطاعم');
      expect(category.slug, 'restaurants');
      expect(category.isTransport, isFalse);
      expect(category.syncVersion, 15);
      expect(category.updatedAt, isNotNull);
    });

    test('maps a business and its referenced category', () {
      final business = Business.fromSupabase({
        'id': 'business-id',
        'category_id': 'category-id',
        'name': 'مطعم تجريبي',
        'description': 'وصف النشاط',
        'phone': '777333444',
        'whatsapp': '777333444',
        'address': 'الشارع العام',
        'is_featured': true,
        'created_at': '2026-08-02T18:00:00Z',
        'updated_at': '2026-08-03T20:01:00Z',
        'sync_version': 16,
        'categories': {
          'id': 'category-id',
          'name_ar': 'مطاعم',
          'slug': 'restaurants',
          'icon_name': 'restaurant',
        },
      });

      expect(business.category, 'مطاعم');
      expect(business.categorySlug, 'restaurants');
      expect(business.place, 'الشارع العام');
      expect(business.isFeatured, isTrue);
      expect(business.isRemote, isTrue);
      expect(business.syncVersion, 16);
    });

    test('maps an advertisement and applies its time window', () {
      final advertisement = DirectoryAdvertisement.fromSupabase({
        'id': 'advertisement-id',
        'title': 'إعلان تجريبي',
        'sort_order': 1,
        'is_active': true,
        'starts_at': '2026-08-03T19:00:00Z',
        'ends_at': '2026-08-03T23:00:00Z',
        'sync_version': 17,
      });

      expect(advertisement.syncVersion, 17);
      expect(
        advertisement.isVisibleAt(DateTime.utc(2026, 8, 3, 21)),
        isTrue,
      );
      expect(
        advertisement.isVisibleAt(DateTime.utc(2026, 8, 4)),
        isFalse,
      );
    });
  });
}
