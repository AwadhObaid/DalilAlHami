import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/repositories/account_repository.dart';
import 'package:hami_guide/models/account_profile.dart';

void main() {
  test('استثناء الحساب الموقوف يحتفظ بالملف ويعرض رسالة واضحة', () {
    const profile = AccountProfile(
      id: 'user-1',
      fullName: 'مستخدم موقوف',
      phone: '777000001',
      role: 'user',
      isActive: false,
    );

    final failure = AccountSuspendedFailure(profile);

    expect(failure.profile, same(profile));
    expect(failure.message, contains('تم إيقاف هذا الحساب'));
    expect(failure.message, contains('إدارة الأنشطة'));
  });

  test('الحذف الظاهري يعرض حالة منفصلة ويمنع استخدام الحساب', () {
    final profile = AccountProfile.fromMap(<String, dynamic>{
      'id': 'user-2',
      'full_name': 'مستخدم محذوف ظاهريًا',
      'phone': '777000002',
      'role': 'user',
      'is_active': false,
      'deleted_at': '2026-08-08T01:00:00Z',
      'suspension_reason': 'طلب حذف الحساب',
    });

    final failure = AccountSuspendedFailure(profile);

    expect(profile.isDeleted, isTrue);
    expect(profile.canUseAccount, isFalse);
    expect(failure.message, contains('حذف هذا الحساب ظاهريًا'));
    expect(failure.message, contains('استعادة الحساب'));
  });
}
