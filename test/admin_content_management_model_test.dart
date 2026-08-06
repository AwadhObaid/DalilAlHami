import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/admin_content_management.dart';

void main() {
  test('نموذج القسم يحسب الأرشفة والحذف الآمن', () {
    final category = AdminCategoryItem.fromMap(
      <String, dynamic>{
        'id': 'cat-1',
        'name_ar': 'المطاعم',
        'slug': 'restaurants',
        'icon_name': 'restaurant',
        'sort_order': 2,
        'display_group': 'services',
        'is_active': false,
        'deleted_at': '2026-08-06T00:00:00Z',
        'updated_at': '2026-08-06T00:00:00Z',
      },
      businessCount: 0,
    );

    expect(category.isArchived, isTrue);
    expect(category.canDeletePermanently, isTrue);
    expect(category.groupLabel, 'الخدمات');
  });

  test('نموذج النشاط يعرض الحالة والمالك وقابلية التمييز', () {
    final business = AdminBusinessItem.fromMap(
      <String, dynamic>{
        'id': 'business-1',
        'owner_id': 'owner-1',
        'category_id': 'cat-1',
        'name': 'مطعم الحامي',
        'description': '',
        'phone': '777111111',
        'whatsapp': '',
        'address': 'الحامي',
        'status': 'approved',
        'is_featured': false,
        'is_active': true,
        'created_at': '2026-08-06T00:00:00Z',
        'updated_at': '2026-08-06T00:00:00Z',
        'categories': <String, dynamic>{'name_ar': 'المطاعم'},
      },
      ownerName: 'صاحب المطعم',
    );

    expect(business.statusLabel, 'معتمد');
    expect(business.displayOwner, 'صاحب المطعم');
    expect(business.canBeFeatured, isTrue);
  });

  test('نتيجة RPC الإدارية تقرأ الخريطة بصورة موحدة', () {
    final result = AdminContentMutationResult.fromRpc(
      <String, dynamic>{
        'entity_id': 'cat-1',
        'entity_type': 'category',
        'action': 'created',
        'message': 'تمت إضافة القسم بنجاح.',
      },
    );

    expect(result.entityId, 'cat-1');
    expect(result.action, 'created');
  });
}
