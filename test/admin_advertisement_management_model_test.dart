import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/admin_advertisement_management.dart';

void main() {
  test('يحوّل الإعلان وموضعه ووجهته من بيانات Supabase', () {
    final advertisement = AdminAdvertisementItem.fromMap({
      'id': 'ad-1',
      'business_id': 'business-1',
      'title': 'عرض مطعم الحامي',
      'image_path': 'offers/ad-1.jpg',
      'target_url': null,
      'placement': 'business_list',
      'starts_at': '2026-08-06T10:00:00Z',
      'ends_at': '2026-08-08T10:00:00Z',
      'sort_order': 4,
      'is_active': true,
      'created_at': '2026-08-06T09:00:00Z',
      'updated_at': '2026-08-06T09:30:00Z',
      'businesses': {'id': 'business-1', 'name': 'مطعم الحامي'},
    });

    expect(advertisement.placement, AdminAdvertisementPlacement.businessList);
    expect(advertisement.targetType, AdminAdvertisementTargetType.business);
    expect(advertisement.targetLabel, 'مطعم الحامي');
    expect(advertisement.sortOrder, 4);
  });

  test('يميز الإعلان الظاهر والمجدول والمنتهي والمتوقف', () {
    final now = DateTime.utc(2026, 8, 6, 12);

    AdminAdvertisementItem item({
      bool active = true,
      DateTime? startsAt,
      DateTime? endsAt,
    }) {
      return AdminAdvertisementItem(
        id: 'ad',
        title: 'إعلان',
        imagePath: 'ad.jpg',
        placement: AdminAdvertisementPlacement.homeTop,
        sortOrder: 0,
        isActive: active,
        startsAt: startsAt,
        endsAt: endsAt,
        createdAt: now,
        updatedAt: now,
      );
    }

    expect(
      item().runtimeStateAt(now),
      AdminAdvertisementRuntimeState.visible,
    );
    expect(
      item(startsAt: now.add(const Duration(hours: 1))).runtimeStateAt(now),
      AdminAdvertisementRuntimeState.scheduled,
    );
    expect(
      item(endsAt: now.subtract(const Duration(minutes: 1)))
          .runtimeStateAt(now),
      AdminAdvertisementRuntimeState.ended,
    );
    expect(
      item(active: false).runtimeStateAt(now),
      AdminAdvertisementRuntimeState.inactive,
    );
  });

  test('تحويل مواضع الإعلانات يحافظ على قيم RPC', () {
    expect(AdminAdvertisementPlacement.homeTop.rpcValue, 'home_top');
    expect(AdminAdvertisementPlacement.homeMiddle.rpcValue, 'home_middle');
    expect(AdminAdvertisementPlacement.category.rpcValue, 'category');
    expect(
      AdminAdvertisementPlacement.businessList.rpcValue,
      'business_list',
    );
  });
}
