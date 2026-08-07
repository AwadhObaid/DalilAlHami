import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/admin/admin_notification_management_page.dart';
import 'package:hami_guide/models/account_profile.dart';
import 'package:hami_guide/models/admin_advertisement_management.dart';
import 'package:hami_guide/models/admin_notification_management.dart';

void main() {
  const adminProfile = AccountProfile(
    id: 'admin-1',
    fullName: 'مدير دليل الحامي',
    phone: '777000000',
    role: 'admin',
    isActive: true,
    email: 'admin@example.com',
  );

  testWidgets('admin notification composer and history render', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminNotificationManagementPage(
          profileLoader: () async => adminProfile,
          usersLoader: () async => const <AdminNotificationUserOption>[
            AdminNotificationUserOption(
              id: 'user-1',
              name: 'مستخدم تجريبي',
              email: 'user@example.com',
            ),
          ],
          businessesLoader: () async =>
              const <AdminAdvertisementBusinessOption>[
            AdminAdvertisementBusinessOption(
              id: 'business-1',
              name: 'نشاط تجريبي',
            ),
          ],
          historyLoader: () async => <AdminNotificationHistoryItem>[
            AdminNotificationHistoryItem(
              id: 'notification-1',
              title: 'إشعار سابق',
              body: 'تم إرسال هذا الإشعار.',
              targetType: 'public',
              navigationType: 'notifications',
              deliveryStatus: 'sent',
              attemptCount: 1,
              successCount: 1,
              createdAt: DateTime(2026, 8, 7, 18),
            ),
          ],
          sender: ({
            required title,
            required body,
            required audience,
            required navigation,
            targetUserId,
            businessId,
          }) async =>
              const AdminNotificationSendResult(
            notificationId: 'new-notification',
            message: 'تم إرسال الإشعار.',
            deliveryStatus: 'sent',
            attemptCount: 1,
            successCount: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إدارة الإشعارات'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('admin-notification-title-field')),
      findsOneWidget,
    );
    expect(find.text('إشعار سابق'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
