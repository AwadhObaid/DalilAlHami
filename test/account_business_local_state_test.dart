import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/account_business.dart';

void main() {
  test('يعرض النشاط المحلي بحالة انتظار المزامنة', () {
    const business = AccountBusiness(
      id: 'business-id',
      ownerId: 'user-id',
      categoryId: 'category-id',
      categoryName: 'خدمات',
      name: 'نشاط',
      description: '',
      phone: '777000000',
      whatsapp: '777000000',
      address: 'الحامي',
      status: 'local_pending',
      isActive: true,
    );

    expect(business.isWaitingForSync, isTrue);
    expect(business.statusLabel, 'بانتظار المزامنة');
  });
}
