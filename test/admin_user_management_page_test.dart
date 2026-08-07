import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/admin/admin_user_management_page.dart';
import 'package:hami_guide/models/account_profile.dart';
import 'package:hami_guide/models/admin_user_management.dart';

void main() {
  const adminProfile = AccountProfile(
    id: 'admin-1',
    fullName: 'مدير دليل الحامي',
    phone: '777000000',
    role: 'admin',
    isActive: true,
    email: 'admin@example.com',
  );

  AdminManagedUser user({
    required String id,
    required bool isCurrentUser,
    bool isActive = true,
    String role = 'user',
    DateTime? deletedAt,
  }) {
    return AdminManagedUser(
      id: id,
      fullName: isCurrentUser ? 'مدير دليل الحامي' : 'مالك نشاط',
      email: isCurrentUser ? 'admin@example.com' : 'owner@example.com',
      phone: isCurrentUser ? '777000000' : '777000001',
      role: role,
      isActive: isActive,
      businessCount: isCurrentUser ? 0 : 2,
      providers: const <String>['google'],
      isCurrentUser: isCurrentUser,
      deletedAt: deletedAt,
    );
  }

  testWidgets('يعرض الملخص ويمنع تعديل الحساب الحالي', (tester) async {
    final users = <AdminManagedUser>[
      user(id: 'admin-1', isCurrentUser: true, role: 'admin'),
      user(id: 'user-1', isCurrentUser: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminUserManagementPage(
          profileLoader: () async => adminProfile,
          usersLoader: ({
            query = '',
            status = 'all',
            role = 'all',
            page = 1,
            perPage = 20,
          }) async =>
              AdminUserPage(
            users: users,
            page: page,
            perPage: perPage,
            total: users.length,
            activeCount: 2,
            suspendedCount: 0,
            deletedCount: 0,
            adminCount: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إدارة المستخدمين'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('admin-user-summary')),
      findsOneWidget,
    );
    expect(find.text('2 حساب'), findsOneWidget);

    final list = find.byKey(
      const PageStorageKey<String>('admin-user-management-list'),
    );
    final ownStatus = find.byKey(
      const ValueKey<String>('admin-user-status-admin-1'),
    );
    await tester.dragUntilVisible(ownStatus, list, const Offset(0, -180));
    await tester.ensureVisible(ownStatus);
    await tester.pumpAndSettle();

    final ownStatusButton = tester.widget<OutlinedButton>(ownStatus);
    final ownRoleButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey<String>('admin-user-role-admin-1')),
    );
    expect(ownStatusButton.onPressed, isNull);
    expect(ownRoleButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('إيقاف مستخدم يطلب سببًا وينفذ العملية ثم يعيد التحميل', (
    tester,
  ) async {
    var targetActive = true;
    var loadCount = 0;
    String? submittedReason;

    Future<AdminUserPage> loader({
      String query = '',
      String status = 'all',
      String role = 'all',
      int page = 1,
      int perPage = 20,
    }) async {
      loadCount += 1;
      return AdminUserPage(
        users: <AdminManagedUser>[
          user(
            id: 'user-1',
            isCurrentUser: false,
            isActive: targetActive,
          ),
        ],
        page: page,
        perPage: perPage,
        total: 1,
        activeCount: targetActive ? 1 : 0,
        suspendedCount: targetActive ? 0 : 1,
        deletedCount: 0,
        adminCount: 1,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminUserManagementPage(
          profileLoader: () async => adminProfile,
          usersLoader: loader,
          statusExecutor: ({
            required userId,
            required isActive,
            reason,
          }) async {
            expect(userId, 'user-1');
            targetActive = isActive;
            submittedReason = reason;
            return const AdminUserActionResult(
              userId: 'user-1',
              action: 'suspended',
              message: 'تم إيقاف الحساب.',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byKey(
      const PageStorageKey<String>('admin-user-management-list'),
    );
    final statusButton = find.byKey(
      const ValueKey<String>('admin-user-status-user-1'),
    );
    await tester.dragUntilVisible(statusButton, list, const Offset(0, -180));
    await tester.ensureVisible(statusButton);
    await tester.pumpAndSettle();
    await tester.tap(statusButton.hitTestable());
    await tester.pumpAndSettle();

    final suspensionReason = find.byKey(
      const ValueKey<String>('admin-user-suspension-reason'),
    );
    final suspensionConfirm = find.byKey(
      const ValueKey<String>('admin-user-status-confirm'),
    );

    await tester.enterText(suspensionReason, 'سبب');
    await tester.tap(suspensionConfirm);
    await tester.pumpAndSettle();
    expect(
      find.text('اكتب سببًا واضحًا لا يقل عن خمسة أحرف.'),
      findsOneWidget,
    );
    expect(suspensionReason, findsOneWidget);
    expect(targetActive, isTrue);
    expect(tester.takeException(), isNull);

    await tester.enterText(suspensionReason, 'مخالفة شروط الاستخدام');
    await tester.tap(suspensionConfirm);
    await tester.pumpAndSettle();

    expect(targetActive, isFalse);
    expect(submittedReason, 'مخالفة شروط الاستخدام');
    expect(loadCount, greaterThanOrEqualTo(2));
    expect(find.text('تم إيقاف الحساب.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('الحذف الظاهري يطلب سببًا وينفذ ثم يعيد التحميل', (
    tester,
  ) async {
    var targetDeleted = false;
    var loadCount = 0;
    String? submittedReason;

    Future<AdminUserPage> loader({
      String query = '',
      String status = 'all',
      String role = 'all',
      int page = 1,
      int perPage = 20,
    }) async {
      loadCount += 1;
      return AdminUserPage(
        users: <AdminManagedUser>[
          user(
            id: 'user-2',
            isCurrentUser: false,
            isActive: !targetDeleted,
            deletedAt: targetDeleted ? DateTime.utc(2026, 8, 7, 1) : null,
          ),
        ],
        page: page,
        perPage: perPage,
        total: 1,
        activeCount: targetDeleted ? 0 : 1,
        suspendedCount: 0,
        deletedCount: targetDeleted ? 1 : 0,
        adminCount: 1,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminUserManagementPage(
          profileLoader: () async => adminProfile,
          usersLoader: loader,
          deleteExecutor: ({
            required userId,
            required isDeleted,
            reason,
          }) async {
            expect(userId, 'user-2');
            targetDeleted = isDeleted;
            submittedReason = reason;
            return const AdminUserActionResult(
              userId: 'user-2',
              action: 'soft_deleted',
              message: 'تم حذف الحساب ظاهريًا.',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byKey(
      const PageStorageKey<String>('admin-user-management-list'),
    );
    final deleteButton = find.byKey(
      const ValueKey<String>('admin-user-delete-user-2'),
    );
    await tester.dragUntilVisible(deleteButton, list, const Offset(0, -180));
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton.hitTestable());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('admin-user-delete-reason')),
      'طلب رسمي بحذف الحساب',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('admin-user-delete-confirm')),
    );
    await tester.pumpAndSettle();

    expect(targetDeleted, isTrue);
    expect(submittedReason, 'طلب رسمي بحذف الحساب');
    expect(loadCount, greaterThanOrEqualTo(2));
    expect(find.text('تم حذف الحساب ظاهريًا.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('إدارة المستخدمين تتحمل شاشة ضيقة وخطًا مكبرًا', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 720),
            textScaler: TextScaler.linear(1.3),
          ),
          child: AdminUserManagementPage(
            profileLoader: () async => adminProfile,
            usersLoader: ({
              query = '',
              status = 'all',
              role = 'all',
              page = 1,
              perPage = 20,
            }) async =>
                AdminUserPage(
              users: <AdminManagedUser>[
                user(id: 'user-1', isCurrentUser: false),
              ],
              page: page,
              perPage: perPage,
              total: 1,
              activeCount: 1,
              suspendedCount: 0,
              deletedCount: 0,
              adminCount: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إدارة المستخدمين'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final list = find.byKey(
      const PageStorageKey<String>('admin-user-management-list'),
    );
    final statusButton = find.byKey(
      const ValueKey<String>('admin-user-status-user-1'),
    );
    await tester.dragUntilVisible(statusButton, list, const Offset(0, -180));
    await tester.ensureVisible(statusButton);
    await tester.pumpAndSettle();
    await tester.tap(statusButton.hitTestable());
    await tester.pumpAndSettle();

    final reasonField = find.byKey(
      const ValueKey<String>('admin-user-suspension-reason'),
    );
    expect(reasonField, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(reasonField, 'اختبار دورة حياة الحوار');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('admin-user-suspension-reason-cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(reasonField, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
