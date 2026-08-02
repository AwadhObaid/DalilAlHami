import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/business.dart';
import 'package:hami_guide/models/service_category.dart';

void main() {
  group('Supabase model mapping', () {
    test('maps a service category', () {
      final category = ServiceCategory.fromSupabase({
        'id': 'category-id',
        'name_ar': 'مطاعم',
        'slug': 'restaurants',
        'icon_name': 'restaurant',
        'sort_order': 40,
        'display_group': 'services',
      });

      expect(category.id, 'category-id');
      expect(category.name, 'مطاعم');
      expect(category.slug, 'restaurants');
      expect(category.isTransport, isFalse);
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
    });
  });
}
