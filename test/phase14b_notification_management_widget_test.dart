import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/admin/admin_notification_management_page.dart';
import 'package:hami_guide/features/notifications/notification_center_page.dart';
import 'package:hami_guide/models/account_profile.dart';
import 'package:hami_guide/models/admin_advertisement_management.dart';
import 'package:hami_guide/models/admin_notification_management.dart';
import 'package:hami_guide/models/app_notification.dart';

void main() {
  final notifications = <AppNotification>[
    AppNotification(
      id: 'n1',
      title: 'إشعار أول',
      body: 'رسالة أولى',
      targetType: 'public',
      navigationType: 'notifications',
      createdAt: DateTime(2026, 8, 11, 16),
      isRead: false,
    ),
    AppNotification(
      id: 'n2',
      title: 'إشعار ثانٍ',
      body: 'رسالة ثانية',
      targetType: 'user',
      navigationType: 'home',
      createdAt: DateTime(2026, 8, 11, 15),
      isRead: true,
    ),
  ];

  testWidgets('user can delete one notification without affecting the rest',
      (tester) async {
    final dismissed = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NotificationCenterPage(
          loader: () async => notifications,
          readExecutor: (_) async => true,
          readAllExecutor: () async => 0,
          dismissExecutor: (id) async {
            dismissed.add(id);
            return true;
          },
          dismissManyExecutor: (_) async => 0,
          dismissAllExecutor: () async => 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('notification-delete-n1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('notification-delete-confirm')),
    );
    await tester.pumpAndSettle();

    expect(dismissed, <String>['n1']);
    expect(
      find.byKey(const ValueKey<String>('notification-item-n1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('notification-item-n2')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('user can long-press, multi-select, and delete selected',
      (tester) async {
    final dismissed = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NotificationCenterPage(
          loader: () async => notifications,
          readExecutor: (_) async => true,
          readAllExecutor: () async => 0,
          dismissExecutor: (_) async => true,
          dismissManyExecutor: (ids) async {
            dismissed.addAll(ids);
            return ids.length;
          },
          dismissAllExecutor: () async => 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('notification-item-n1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('notification-delete-selected')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('notification-item-n2')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('notification-delete-selected')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('notification-delete-selected-confirm'),
      ),
    );
    await tester.pumpAndSettle();

    expect(dismissed.toSet(), <String>{'n1', 'n2'});
    expect(find.text('لا توجد إشعارات حتى الآن'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('user can clear all notifications', (tester) async {
    var clearCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NotificationCenterPage(
          loader: () async => notifications,
          readExecutor: (_) async => true,
          readAllExecutor: () async => 0,
          dismissExecutor: (_) async => true,
          dismissManyExecutor: (_) async => 0,
          dismissAllExecutor: () async {
            clearCalls += 1;
            return 2;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('notification-clear-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('notification-clear-all-confirm')),
    );
    await tester.pumpAndSettle();

    expect(clearCalls, 1);
    expect(find.text('لا توجد إشعارات حتى الآن'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  const adminProfile = AccountProfile(
    id: 'admin-1',
    fullName: 'مدير دليل الحامي',
    phone: '777000000',
    role: 'admin',
    isActive: true,
    email: 'admin@example.com',
  );

  AdminNotificationManagementPage adminPage({
    required Future<int> Function(List<String>) hider,
    required Future<int> Function() clearer,
  }) {
    return AdminNotificationManagementPage(
      profileLoader: () async => adminProfile,
      usersLoader: () async => const <AdminNotificationUserOption>[],
      businessesLoader: () async => const <AdminAdvertisementBusinessOption>[],
      historyLoader: () async => <AdminNotificationHistoryItem>[
        AdminNotificationHistoryItem(
          id: 'notification-1',
          title: 'إشعار إداري أول',
          body: 'محتوى السجل الأول',
          targetType: 'public',
          navigationType: 'notifications',
          deliveryStatus: 'sent',
          attemptCount: 1,
          successCount: 1,
          createdAt: DateTime(2026, 8, 11, 16),
        ),
        AdminNotificationHistoryItem(
          id: 'notification-2',
          title: 'إشعار إداري ثانٍ',
          body: 'محتوى السجل الثاني',
          targetType: 'public',
          navigationType: 'notifications',
          deliveryStatus: 'sent',
          attemptCount: 1,
          successCount: 1,
          createdAt: DateTime(2026, 8, 11, 15),
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
        notificationId: 'unused',
        message: 'unused',
        deliveryStatus: 'sent',
        attemptCount: 0,
        successCount: 0,
      ),
      historyHider: hider,
      historyClearer: clearer,
    );
  }

  testWidgets('admin can multi-select and hide history only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final hidden = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: adminPage(
          hider: (ids) async {
            hidden.addAll(ids);
            return ids.length;
          },
          clearer: () async => 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byKey(
      const PageStorageKey<String>('admin-notification-management-list'),
    );
    final first = find.byKey(
      const ValueKey<String>(
        'admin-notification-history-item-notification-1',
      ),
    );
    await tester.dragUntilVisible(first, list, const Offset(0, -240));
    await tester.pumpAndSettle();

    await tester.longPress(first);
    await tester.pumpAndSettle();

    final second = find.byKey(
      const ValueKey<String>(
        'admin-notification-history-item-notification-2',
      ),
    );
    await tester.dragUntilVisible(
      second,
      list,
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(second);
    await tester.pumpAndSettle();
    await tester.tap(second.hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('admin-notification-history-hide-selected'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'admin-notification-history-hide-selected-confirm',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(hidden.toSet(), <String>{'notification-1', 'notification-2'});
    expect(first, findsNothing);
    expect(second, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin can clear history without deleting notification rows',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var clearCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: adminPage(
          hider: (_) async => 0,
          clearer: () async {
            clearCalls += 1;
            return 2;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byKey(
      const PageStorageKey<String>('admin-notification-management-list'),
    );
    final clear = find.byKey(
      const ValueKey<String>('admin-notification-history-clear'),
    );
    await tester.dragUntilVisible(clear, list, const Offset(0, -220));
    await tester.pumpAndSettle();

    await tester.tap(clear);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('admin-notification-history-clear-confirm'),
      ),
    );
    await tester.pumpAndSettle();

    expect(clearCalls, 1);
    expect(
        find.text('لم يتم إرسال إشعارات من لوحة الإدارة بعد.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
