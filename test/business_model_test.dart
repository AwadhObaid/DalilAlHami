import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/business.dart';

void main() {
  test('يستخدم رقم الاتصال كبديل لواتساب عند غياب رقم واتساب', () {
    const business = Business(
      id: '1',
      name: 'مطعم الحامي',
      phone: '777123456',
      category: 'مطاعم',
      place: 'الحامي',
    );

    expect(business.hasPhone, isTrue);
    expect(business.hasWhatsApp, isTrue);
    expect(business.whatsappContact, '777123456');
  });

  test('البحث العربي يتجاهل اختلاف الهمزات والتشكيل', () {
    const business = Business(
      id: '1',
      name: 'مَطْعَم الأمانة',
      phone: '777123456',
      category: 'مطاعم',
      place: 'الحامي',
    );

    expect(business.matchesSearch('الامانه'), isTrue);
  });

  test('يقرأ القيم المنطقية المخزنة كأرقام في SQLite', () {
    final business = Business.fromMap({
      'id': 'sqlite-business',
      'name': 'نشاط محلي',
      'phone': '777000111',
      'category': 'خدمات',
      'place': 'الحامي',
      'is_featured': 1,
      'is_remote': 1,
    });

    expect(business.isFeatured, isTrue);
    expect(business.isRemote, isTrue);
  });
}
