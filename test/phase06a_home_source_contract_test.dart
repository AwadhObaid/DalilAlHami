import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('الصفحة الرئيسية تحافظ على التصميم المعتمد ومسار الإعلانات', () {
    final dashboard = File(
      'lib/features/home/home_dashboard_page.dart',
    ).readAsStringSync();
    final navigation = File(
      'lib/features/home/home_screen.dart',
    ).readAsStringSync();
    final advertisement = File(
      'lib/features/home/widgets/ad_slider.dart',
    ).readAsStringSync();

    expect(dashboard, contains('الفئات المميزة'));
    expect(dashboard, isNot(contains('خدمات النقل')));
    expect(dashboard, contains('أنشطة قريبة منك'));
    expect(dashboard, contains('StickyAdvertisementHeader'));
    expect(dashboard, contains('home-explore-directory-footer'));
    expect(dashboard, contains('featured-categories-view-all'));
    expect(advertisement, contains('إعلان محلي تديره إدارة دليل الحامي'));
    expect(navigation, contains("label: 'إضافة نشاط'"));
    expect(navigation, contains("label: 'أنشطتي'"));
  });
}
