import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/sync/directory_sync_delta.dart';

void main() {
  test('يحوّل استجابة RPC إلى تغييرات تزايدية', () {
    final delta = DirectorySyncDelta.fromRpc({
      'server_version': 42,
      'is_full_snapshot': false,
      'categories': [
        {
          'id': 'category-1',
          'name_ar': 'مطاعم',
          'slug': 'restaurants',
          'icon_name': 'restaurant',
          'sort_order': 10,
          'display_group': 'services',
          'updated_at': '2026-08-03T20:00:00Z',
          'sync_version': 40,
        },
      ],
      'deleted_category_ids': ['category-deleted'],
      'businesses': [
        {
          'id': 'business-1',
          'category_id': 'category-1',
          'name': 'مطعم الحامي',
          'phone': '777000111',
          'address': 'الحامي',
          'updated_at': '2026-08-03T20:01:00Z',
          'sync_version': 41,
          'categories': {
            'id': 'category-1',
            'name_ar': 'مطاعم',
            'slug': 'restaurants',
            'icon_name': 'restaurant',
          },
        },
      ],
      'deleted_business_ids': ['business-deleted'],
      'advertisements': [
        {
          'id': 'advertisement-1',
          'title': 'إعلان متزامن',
          'sort_order': 1,
          'is_active': true,
          'sync_version': 42,
        },
      ],
      'deleted_advertisement_ids': ['advertisement-deleted'],
    });

    expect(delta.serverVersion, 42);
    expect(delta.isFullSnapshot, isFalse);
    expect(delta.categories.single.name, 'مطاعم');
    expect(delta.businesses.single.category, 'مطاعم');
    expect(delta.advertisements.single.title, 'إعلان متزامن');
    expect(delta.deletedCategoryIds, contains('category-deleted'));
    expect(delta.deletedBusinessIds, contains('business-deleted'));
    expect(
      delta.deletedAdvertisementIds,
      contains('advertisement-deleted'),
    );
    expect(delta.changeCount, 6);
  });

  test('يرفض استجابة RPC غير الصالحة', () {
    expect(
      () => DirectorySyncDelta.fromRpc('invalid'),
      throwsFormatException,
    );
  });
}
