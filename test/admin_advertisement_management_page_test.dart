import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/admin/admin_advertisement_management_page.dart';
import 'package:hami_guide/models/account_profile.dart';
import 'package:hami_guide/models/admin_advertisement_management.dart';
import 'package:hami_guide/models/admin_content_management.dart';

void main() {
  const admin = AccountProfile(
    id: 'admin-1',
    fullName: 'مدير دليل الحامي',
    phone: '777000000',
    role: 'admin',
    isActive: true,
  );

  final advertisement = AdminAdvertisementItem(
    id: 'ad-1',
    title: 'عرض مطعم الحامي',
    imagePath: 'advertisements/ad-1.jpg',
    placement: AdminAdvertisementPlacement.homeTop,
    sortOrder: 1,
    isActive: true,
    targetUrl: 'https://example.com/offer',
    createdAt: DateTime.utc(2026, 8, 6),
    updatedAt: DateTime.utc(2026, 8, 6),
  );

  const businesses = <AdminAdvertisementBusinessOption>[
    AdminAdvertisementBusinessOption(
      id: 'business-1',
      name: 'مطعم الحامي',
    ),
  ];

  testWidgets('المدير يرى الإعلانات ويضيف إعلانًا', (tester) async {
    AdminAdvertisementDraft? submitted;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminAdvertisementManagementPage(
          profileLoader: () async => admin,
          advertisementsLoader: () async => <AdminAdvertisementItem>[
            advertisement,
          ],
          businessesLoader: () async => businesses,
          saveAction: (draft) async {
            submitted = draft;
            return const AdminContentMutationResult(
              entityId: 'ad-2',
              entityType: 'advertisement',
              action: 'created',
              message: 'تمت إضافة الإعلان وتفعيله.',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إدارة الحملات الإعلانية'), findsOneWidget);
    expect(find.text('عرض مطعم الحامي'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-add-advertisement-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('admin-add-advertisement-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-advertisement-placement-field')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-advertisement-title-field')),
      'إعلان جديد',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-advertisement-image-field')),
      'advertisements/new-ad.jpg',
    );
    await tester.tap(
      find.byKey(const ValueKey('admin-save-advertisement-button')),
    );
    await tester.pumpAndSettle();

    expect(submitted?.title, 'إعلان جديد');
    expect(submitted?.placement, AdminAdvertisementPlacement.homeTop);
    expect(submitted?.targetType, AdminAdvertisementTargetType.none);
    expect(tester.takeException(), isNull);
  });

  testWidgets('إيقاف الإعلان يصل إلى الإجراء الإداري', (tester) async {
    String? submittedId;
    bool? submittedActive;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminAdvertisementManagementPage(
          profileLoader: () async => admin,
          advertisementsLoader: () async => <AdminAdvertisementItem>[
            advertisement,
          ],
          businessesLoader: () async => businesses,
          activationAction: (advertisementId, isActive) async {
            submittedId = advertisementId;
            submittedActive = isActive;
            return const AdminContentMutationResult(
              entityId: 'ad-1',
              entityType: 'advertisement',
              action: 'deactivated',
              message: 'تم إيقاف الإعلان.',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(
      const ValueKey<String>('admin-advertisement-toggle-ad-1'),
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final confirm = find.byKey(
      const ValueKey<String>('admin-advertisement-deactivate-confirm'),
    );
    expect(confirm, findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(submittedId, 'ad-1');
    expect(submittedActive, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('الحساب العادي لا يستطيع إدارة الإعلانات', (tester) async {
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
        home: AdminAdvertisementManagementPage(
          profileLoader: () async => user,
          advertisementsLoader: () async {
            loaded = true;
            return <AdminAdvertisementItem>[advertisement];
          },
          businessesLoader: () async => businesses,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-advertisements-denied')),
      findsOneWidget,
    );
    expect(loaded, isFalse);
  });
}
