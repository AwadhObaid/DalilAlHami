import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/admin_user_management.dart';

void main() {
  test('يقرأ صفحة المستخدمين وبيانات المصادقة بأمان', () {
    final page = AdminUserPage.fromResponse(<String, dynamic>{
      'users': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'user-1',
          'full_name': 'مستخدم تجريبي',
          'email': 'user@example.com',
          'phone': '777000001',
          'role': 'user',
          'is_active': false,
          'business_count': 2,
          'providers': <String>['google', 'email'],
          'is_current_user': false,
          'suspension_reason': 'مخالفة شروط الاستخدام',
          'suspended_at': '2026-08-07T00:10:00Z',
          'created_at': '2026-08-01T12:00:00Z',
          'last_sign_in_at': '2026-08-06T20:00:00Z',
          'banned_until': '2126-08-07T00:00:00Z',
        },
      ],
      'page': 2,
      'per_page': 20,
      'total': 42,
      'active_count': 36,
      'suspended_count': 6,
      'deleted_count': 3,
      'admin_count': 2,
    });

    expect(page.users, hasLength(1));
    expect(page.page, 2);
    expect(page.totalPages, 3);
    expect(page.hasPrevious, isTrue);
    expect(page.hasNext, isTrue);
    expect(page.activeCount, 36);
    expect(page.suspendedCount, 6);
    expect(page.deletedCount, 3);

    final user = page.users.single;
    expect(user.displayName, 'مستخدم تجريبي');
    expect(user.isSuspended, isTrue);
    expect(user.isAuthBanned, isTrue);
    expect(user.statusLabel, 'موقوف');
    expect(user.roleLabel, 'مستخدم');
    expect(user.providers, <String>['google', 'email']);
    expect(user.businessCount, 2);
  });

  test('يقرأ تفاصيل المستخدم والأنشطة وسجل التدقيق', () {
    final detail = AdminManagedUserDetail.fromResponse(<String, dynamic>{
      'user': <String, dynamic>{
        'id': 'user-2',
        'full_name': '',
        'email': 'owner@example.com',
        'role': 'admin',
        'is_active': true,
        'business_count': 1,
        'providers': <String>['google'],
        'is_current_user': false,
      },
      'businesses': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'business-1',
          'name': 'مؤسسة الحامي',
          'status': 'approved',
          'is_active': true,
        },
      ],
      'audit_entries': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'audit-1',
          'action': 'promoted',
          'actor_name': 'مدير النظام',
          'reason': '',
          'created_at': '2026-08-07T00:00:00Z',
        },
      ],
    });

    expect(detail.user.displayName, 'owner');
    expect(detail.user.isAdmin, isTrue);
    expect(detail.businesses.single.name, 'مؤسسة الحامي');
    expect(detail.auditEntries.single.actionLabel, 'منح صلاحية مدير');
  });
  test('يميز الحذف الظاهري عن الإيقاف العادي', () {
    final user = AdminManagedUser.fromMap(<String, dynamic>{
      'id': 'user-deleted',
      'full_name': 'حساب محذوف ظاهريًا',
      'role': 'user',
      'is_active': false,
      'deleted_at': '2026-08-07T01:00:00Z',
    });

    expect(user.isDeleted, isTrue);
    expect(user.isSuspended, isFalse);
    expect(user.statusLabel, 'محذوف ظاهريًا');
  });
}
