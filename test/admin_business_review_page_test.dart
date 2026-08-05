import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/admin/admin_business_review_page.dart';
import 'package:hami_guide/models/account_profile.dart';
import 'package:hami_guide/models/admin_business_review.dart';

void main() {
  const admin = AccountProfile(
    id: 'admin-1',
    fullName: 'مدير دليل الحامي',
    phone: '777000000',
    role: 'admin',
    isActive: true,
  );

  final pendingBusiness = AdminBusinessReviewItem(
    id: 'business-1',
    ownerId: 'owner-1',
    categoryId: 'category-1',
    categoryName: 'المطاعم',
    name: 'مطعم الحامي',
    description: 'وجبات شعبية',
    phone: '777111111',
    whatsapp: '777111111',
    address: 'وسط مدينة الحامي',
    status: 'pending',
    isFeatured: false,
    isActive: true,
    ownerName: 'صاحب المطعم',
    createdAt: DateTime.utc(2026, 8, 5, 18),
    updatedAt: DateTime.utc(2026, 8, 5, 18),
  );

  testWidgets('المدير يرى الأنشطة المعلقة ويفتح التفاصيل', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminBusinessReviewPage(
          profileLoader: () async => admin,
          queueLoader: () async => <AdminBusinessReviewItem>[pendingBusiness],
          detailLoader: (_) async => pendingBusiness,
          reviewAction: (_, decision, reason) async =>
              AdminBusinessReviewResult(
            businessId: pendingBusiness.id,
            previousStatus: 'pending',
            resultingStatus: decision.resultingStatus,
            decision: decision.rpcValue,
            reviewedAt: DateTime.utc(2026, 8, 5, 20),
            reason: reason,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('طلبات بانتظار القرار'), findsOneWidget);
    expect(find.text('مطعم الحامي'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('admin-pending-business-business-1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('مطعم الحامي'));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل مراجعة النشاط'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('approve-business-review-button'),
      ),
      findsOneWidget,
    );
    expect(find.text('صاحب المطعم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('الحساب العادي لا يستطيع فتح قائمة المراجعة', (tester) async {
    const user = AccountProfile(
      id: 'user-1',
      fullName: 'مستخدم',
      phone: '777000001',
      role: 'user',
      isActive: true,
    );
    var queueLoaded = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminBusinessReviewPage(
          profileLoader: () async => user,
          queueLoader: () async {
            queueLoaded = true;
            return const <AdminBusinessReviewItem>[];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('admin-review-access-denied')),
      findsOneWidget,
    );
    expect(queueLoaded, isFalse);
  });
}
