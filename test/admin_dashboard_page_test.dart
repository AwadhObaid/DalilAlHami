import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/admin/admin_dashboard_page.dart';
import 'package:hami_guide/models/account_profile.dart';
import 'package:hami_guide/models/admin_dashboard_snapshot.dart';

void main() {
  const adminProfile = AccountProfile(
    id: 'admin-1',
    fullName: 'مدير دليل الحامي',
    phone: '777000000',
    role: 'admin',
    isActive: true,
    email: 'admin@example.com',
  );

  final snapshot = AdminDashboardSnapshot(
    totalUsers: 21,
    activeUsers: 19,
    totalCategories: 8,
    activeCategories: 7,
    totalBusinesses: 34,
    pendingBusinesses: 5,
    approvedBusinesses: 23,
    rejectedBusinesses: 2,
    changesRequestedBusinesses: 1,
    draftBusinesses: 3,
    suspendedBusinesses: 1,
    totalAdvertisements: 6,
    activeAdvertisements: 3,
    loadedAt: DateTime.utc(2026, 8, 5, 20, 0),
  );

  testWidgets('المدير يرى لوحة المؤشرات والوحدات الإدارية', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminDashboardPage(
          profileLoader: () async => adminProfile,
          dashboardLoader: () async => snapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('لوحة تحكم الإدارة'), findsOneWidget);
    expect(find.text('مرحبًا مدير دليل الحامي'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('admin-users-metric')),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('admin-businesses-metric')),
      findsOneWidget,
    );
    final reviewModule = find.byKey(
      const ValueKey<String>('admin-review-businesses-action'),
    );
    await tester.scrollUntilVisible(
      reviewModule,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(reviewModule, findsOneWidget);
    expect(
      find.descendant(
        of: reviewModule,
        matching: find.text('5 معلّق'),
      ),
      findsOneWidget,
    );

    final businessModule = find.byKey(
      const ValueKey<String>('admin-manage-businesses-action'),
    );
    await tester.scrollUntilVisible(
      businessModule,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(businessModule, findsOneWidget);

    final categoryModule = find.byKey(
      const ValueKey<String>('admin-manage-categories-action'),
    );
    await tester.scrollUntilVisible(
      categoryModule,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(categoryModule, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('الحساب العادي يُمنع حتى عند فتح الصفحة مباشرة', (tester) async {
    const normalProfile = AccountProfile(
      id: 'user-1',
      fullName: 'مستخدم عادي',
      phone: '777000001',
      role: 'user',
      isActive: true,
    );
    var dashboardWasRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminDashboardPage(
          profileLoader: () async => normalProfile,
          dashboardLoader: () async {
            dashboardWasRequested = true;
            return snapshot;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('admin-access-denied')),
      findsOneWidget,
    );
    expect(find.text('غير مصرح بالدخول'), findsOneWidget);
    expect(dashboardWasRequested, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'لوحة الإدارة تتحمل شاشة ضيقة وخطًا مكبرًا',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 720),
              textScaler: TextScaler.linear(1.35),
            ),
            child: AdminDashboardPage(
              profileLoader: () async => adminProfile,
              dashboardLoader: () async => snapshot,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ملخص النظام'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
