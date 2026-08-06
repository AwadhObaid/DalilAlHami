import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/admin/admin_category_management_page.dart';
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

  final categories = <AdminCategoryItem>[
    AdminCategoryItem(
      id: 'cat-1',
      name: 'المطاعم',
      slug: 'restaurants',
      iconName: 'restaurant',
      sortOrder: 1,
      displayGroup: 'services',
      isActive: true,
      businessCount: 3,
      activeBusinessCount: 2,
      updatedAt: DateTime.utc(2026, 8, 6),
    ),
    AdminCategoryItem(
      id: 'cat-2',
      name: 'النقل',
      slug: 'transport',
      iconName: 'local_taxi',
      sortOrder: 2,
      displayGroup: 'transport',
      isActive: false,
      businessCount: 0,
      activeBusinessCount: 0,
      updatedAt: DateTime.utc(2026, 8, 6),
      deletedAt: DateTime.utc(2026, 8, 6),
    ),
  ];

  testWidgets('المدير يرى الأقسام ويفتح نموذج الإضافة', (tester) async {
    AdminCategoryDraft? submitted;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminCategoryManagementPage(
          profileLoader: () async => admin,
          categoriesLoader: () async => categories,
          saveAction: (draft) async {
            submitted = draft;
            return const AdminContentMutationResult(
              entityId: 'cat-3',
              entityType: 'category',
              action: 'created',
              message: 'تمت إضافة القسم بنجاح.',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('هيكلة دليل الحامي'), findsOneWidget);
    expect(find.text('المطاعم'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-add-category-button')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('admin-add-category-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-category-icon-field')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const ValueKey('admin-category-name-field')),
      'المقاهي',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-category-slug-field')),
      'cafes',
    );
    await tester.tap(find.byKey(const ValueKey('admin-save-category-button')));
    await tester.pumpAndSettle();

    expect(submitted?.name, 'المقاهي');
    expect(submitted?.slug, 'cafes');
    expect(tester.takeException(), isNull);
  });

  testWidgets('الحساب العادي لا يستطيع إدارة الأقسام', (tester) async {
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
        home: AdminCategoryManagementPage(
          profileLoader: () async => user,
          categoriesLoader: () async {
            loaded = true;
            return categories;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-category-access-denied')),
      findsOneWidget,
    );
    expect(loaded, isFalse);
  });
}
