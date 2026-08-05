import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/account_profile.dart';

void main() {
  test('دور المدير يقبل اختلاف حالة الأحرف والمسافات', () {
    const profile = AccountProfile(
      id: 'admin-1',
      fullName: 'المدير',
      phone: '',
      role: ' Admin ',
      isActive: true,
    );

    expect(profile.isAdmin, isTrue);
  });
}
