import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/admin_business_review.dart';
import 'package:hami_guide/models/account_business.dart';

void main() {
  test('قرار طلب التعديل يستخدم الحالة الواضحة لصاحب النشاط', () {
    expect(
      AdminReviewDecision.requestChanges.rpcValue,
      'request_changes',
    );
    expect(
      AdminReviewDecision.requestChanges.resultingStatus,
      'changes_requested',
    );
    expect(AdminReviewDecision.requestChanges.requiresReason, isTrue);

    const business = AccountBusiness(
      id: 'business-1',
      ownerId: 'owner-1',
      categoryId: 'category-1',
      categoryName: 'خدمات',
      name: 'نشاط تجريبي',
      description: '',
      phone: '777000000',
      whatsapp: '777000000',
      address: 'الحامي',
      status: 'changes_requested',
      isActive: false,
    );

    expect(business.statusLabel, 'يحتاج تعديل');
  });

  test('نتيجة RPC تُقرأ من كائن JSON', () {
    final result = AdminBusinessReviewResult.fromRpc(
      <String, dynamic>{
        'business_id': 'business-1',
        'previous_status': 'pending',
        'resulting_status': 'approved',
        'decision': 'approved',
        'reviewed_at': '2026-08-05T20:00:00Z',
      },
    );

    expect(result.businessId, 'business-1');
    expect(result.previousStatus, 'pending');
    expect(result.resultingStatus, 'approved');
  });
}
