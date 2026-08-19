import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/constants/app_catalog.dart';
import 'package:hami_guide/models/service_category.dart';

void main() {
  const expectedIcons = <String, IconData>{
    'work_outline': Icons.work_outline,
    'photo_camera': Icons.photo_camera,
    'eco': Icons.eco,
    'router': Icons.router,
    'business_center': Icons.business_center,
    'account_balance': Icons.account_balance,
    'card_giftcard': Icons.card_giftcard,
    'emergency': Icons.emergency,
    'outdoor_grill': Icons.outdoor_grill,
    'inventory_2': Icons.inventory_2,
    'home_repair_service': Icons.home_repair_service,
    'flight_takeoff': Icons.flight_takeoff,
    'volunteer_activism': Icons.volunteer_activism,
    'bakery_dining': Icons.bakery_dining,
  };

  const expectedCatalogIcons = <String, String>{
    'freelancework': 'work_outline',
    'studios': 'photo_camera',
    'fruitsvegetables': 'eco',
    'internetnetworks': 'router',
    'privatework': 'business_center',
    'governmentfacilities': 'account_balance',
    'artandgiftoffices': 'card_giftcard',
    'emergency': 'emergency',
    'simpleandgrilled': 'outdoor_grill',
    'wholesale-shops': 'inventory_2',
    'other-services': 'home_repair_service',
    'travelagencies': 'flight_takeoff',
    'associations': 'volunteer_activism',
    'bakeries': 'bakery_dining',
  };

  test('كل مفتاح جديد يعرض أيقونة Material الصحيحة', () {
    for (final entry in expectedIcons.entries) {
      expect(
        ServiceCategory.iconFromName(entry.key),
        entry.value,
        reason: 'مفتاح الأيقونة ${entry.key}',
      );
    }
  });

  test('الكتالوج المحلي يتضمن الأقسام المطلوبة وأيقوناتها', () {
    for (final entry in expectedCatalogIcons.entries) {
      final category = AppCatalog.allCategories.singleWhere(
        (candidate) => candidate.slug == entry.key,
      );

      expect(category.iconName, entry.value, reason: entry.key);
      expect(category.icon, isNot(Icons.category), reason: entry.key);
    }
  });

  test('إضافة الأقسام الجديدة لا تغيّر ترتيب الأقسام الأصلية', () {
    final restaurantIndex = AppCatalog.services.indexWhere(
      (category) => category.slug == 'restaurants',
    );
    final firstNewCategoryIndex = AppCatalog.services.indexWhere(
      (category) => category.slug == 'freelancework',
    );

    expect(restaurantIndex, 3);
    expect(firstNewCategoryIndex, greaterThan(restaurantIndex));
  });

  test('المفتاح غير المعروف يستمر باستخدام أيقونة القسم العامة', () {
    expect(ServiceCategory.iconFromName('unknown-icon'), Icons.category);
  });
}
