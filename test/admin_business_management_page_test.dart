import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/admin/admin_business_management_page.dart';
import 'package:hami_guide/models/account_profile.dart';
import 'package:hami_guide/models/admin_content_management.dart';

void main() {
  const admin = AccountProfile(
    id: 'admin-1',
    fullName: 'مدير دليل الحامي',
    phone: '777000000',
    role: 'admin',
    isActive: true,
  );

  final category = AdminCategoryItem(
    id: 'cat-1',
    name: 'المطاعم',
    slug: 'restaurants',
    iconName: 'restaurant',
    sortOrder: 1,
    displayGroup: 'services',
    isActive: true,
    businessCount: 1,
    activeBusinessCount: 1,
    updatedAt: DateTime.utc(2026, 8, 6),
  );

  final business = AdminBusinessItem(
    id: 'business-1',
    categoryId: 'cat-1',
    categoryName: 'المطاعم',
    name: 'مطعم الحامي',
    description: 'وجبات شعبية',
    phone: '777111111',
    whatsapp: '777111111',
    address: 'وسط الحامي',
    status: 'approved',
    isFeatured: false,
    isActive: true,
    ownerId: 'owner-1',
    ownerName: 'صاحب المطعم',
    createdAt: DateTime.utc(2026, 8, 6),
    updatedAt: DateTime.utc(2026, 8, 6),
  );

  testWidgets('المدير يرى الأنشطة ويضيف نشاطًا معتمدًا', (tester) async {
    AdminBusinessDraft? submitted;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminBusinessManagementPage(
          profileLoader: () async => admin,
          businessesLoader: () async => <AdminBusinessItem>[business],
          categoriesLoader: () async => <AdminCategoryItem>[category],
          saveAction: (draft) async {
            submitted = draft;
            return const AdminContentMutationResult(
              entityId: 'business-2',
              entityType: 'business',
              action: 'created',
              message: 'تمت إضافة النشاط ونشره.',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('محتوى الأنشطة'), findsOneWidget);
    expect(find.text('مطعم الحامي'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-add-business-button')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('admin-add-business-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('admin-business-name-field')),
      'مقهى الساحل',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-business-phone-field')),
      '777222222',
    );
    await tester.tap(find.byKey(const ValueKey('admin-save-business-button')));
    await tester.pumpAndSettle();

    expect(submitted?.name, 'مقهى الساحل');
    expect(submitted?.categoryId, 'cat-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('إيقاف النشاط يحافظ على دورة حياة حقل السبب', (tester) async {
    AdminBusinessManagementAction? submittedAction;
    String? submittedReason;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminBusinessManagementPage(
          profileLoader: () async => admin,
          businessesLoader: () async => <AdminBusinessItem>[business],
          categoriesLoader: () async => <AdminCategoryItem>[category],
          managementAction: (businessId, action, reason) async {
            submittedAction = action;
            submittedReason = reason;
            return const AdminContentMutationResult(
              entityId: 'business-1',
              entityType: 'business',
              action: 'suspend',
              message: 'تم إيقاف النشاط.',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final actionsButton = find.byKey(
      const ValueKey<String>('business-actions-business-1'),
    );
    expect(actionsButton, findsOneWidget);
    await tester.ensureVisible(actionsButton);
    await tester.pumpAndSettle();
    await tester.tap(actionsButton);
    await tester.pumpAndSettle();

    final suspendMenuItem = find.byKey(
      const ValueKey<String>('business-menu-suspend-business-1'),
    );
    expect(suspendMenuItem, findsOneWidget);
    await tester.tap(suspendMenuItem);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('admin-business-suspension-dialog')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('admin-business-suspension-reason')),
      'بيانات النشاط غير محدثة',
    );
    await tester.pump();

    final confirmButton = find.byKey(
      const ValueKey<String>('admin-business-suspension-confirm'),
    );
    expect(confirmButton, findsOneWidget);
    expect(
      tester.widget<FilledButton>(confirmButton).onPressed,
      isNotNull,
    );
    expect(submittedAction, isNull);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(submittedAction, AdminBusinessManagementAction.suspend);
    expect(submittedReason, 'بيانات النشاط غير محدثة');
    expect(tester.takeException(), isNull);
  });

  testWidgets('الحساب العادي لا يستطيع إدارة الأنشطة', (tester) async {
    const user = AccountProfile(
      id: 'user-1',
      fullName: 'مستخدم',
      phone: '777000001',
      role: 'user',
      isActive: true,
    );
    var loaded = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminBusinessManagementPage(
          profileLoader: () async => user,
          businessesLoader: () async {
            loaded = true;
            return <AdminBusinessItem>[business];
          },
          categoriesLoader: () async => <AdminCategoryItem>[category],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-business-access-denied')),
      findsOneWidget,
    );
    expect(loaded, isFalse);
  });
}
