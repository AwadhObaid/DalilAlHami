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

  test('حالة الوصول تراعي الإيقاف والحذف الظاهري', () {
    final deleted = AccountProfile.fromMap(<String, dynamic>{
      'id': 'user-deleted',
      'full_name': 'محذوف',
      'phone': '',
      'role': 'user',
      'is_active': false,
      'deleted_at': '2026-08-08T02:00:00Z',
    });

    expect(deleted.isDeleted, isTrue);
    expect(deleted.canUseAccount, isFalse);
  });
}
