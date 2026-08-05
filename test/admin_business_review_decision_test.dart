import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/admin/admin_business_review_detail_page.dart';
import 'package:hami_guide/models/admin_business_review.dart';

void main() {
  final pendingBusiness = AdminBusinessReviewItem(
    id: 'business-2',
    ownerId: 'owner-2',
    categoryId: 'category-2',
    categoryName: 'الخدمات',
    name: 'خدمة الحامي',
    description: 'خدمة تجريبية للمراجعة',
    phone: '777222222',
    whatsapp: '777222222',
    address: 'الحامي',
    status: 'pending',
    isFeatured: false,
    isActive: true,
    ownerName: 'مالك النشاط',
    createdAt: DateTime.utc(2026, 8, 5, 18),
    updatedAt: DateTime.utc(2026, 8, 5, 18),
  );

  testWidgets('طلب التعديل يتطلب سببًا ويرسله للإجراء الإداري', (tester) async {
    AdminReviewDecision? submittedDecision;
    String? submittedReason;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminBusinessReviewDetailPage(
          initialBusiness: pendingBusiness,
          detailLoader: (_) async => pendingBusiness,
          reviewAction: (_, decision, reason) async {
            submittedDecision = decision;
            submittedReason = reason;
            return AdminBusinessReviewResult(
              businessId: pendingBusiness.id,
              previousStatus: 'pending',
              resultingStatus: decision.resultingStatus,
              decision: decision.rpcValue,
              reviewedAt: DateTime.utc(2026, 8, 5, 20),
              reason: reason,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('request-business-changes-button'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('admin-review-reason-field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('admin-review-reason-field')),
      'يرجى إضافة صورة واضحة وتصحيح رقم التواصل.',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-review-with-reason')),
    );
    await tester.pumpAndSettle();

    expect(submittedDecision, AdminReviewDecision.requestChanges);
    expect(submittedReason, contains('صورة واضحة'));
    expect(tester.takeException(), isNull);
  });
}
