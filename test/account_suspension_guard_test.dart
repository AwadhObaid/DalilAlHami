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

    const failure = AccountSuspendedFailure(profile);

    expect(failure.profile, same(profile));
    expect(failure.message, contains('تم إيقاف هذا الحساب'));
    expect(failure.message, contains('تسجيل الخروج'));
  });
}
