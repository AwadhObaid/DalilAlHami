import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/notifications/notification_center_page.dart';
import 'package:hami_guide/models/app_notification.dart';

void main() {
  final items = <AppNotification>[
    AppNotification(
      id: 'n1',
      title: 'إشعار غير مقروء',
      body: 'هذه رسالة اختبارية للمركز.',
      targetType: 'public',
      navigationType: 'notifications',
      createdAt: DateTime(2026, 8, 7, 18),
      isRead: false,
    ),
    AppNotification(
      id: 'n2',
      title: 'إشعار مقروء',
      body: 'رسالة سابقة.',
      targetType: 'user',
      navigationType: 'home',
      createdAt: DateTime(2026, 8, 7, 17),
      isRead: true,
    ),
  ];

  testWidgets('center shows unread state and marks one item read',
      (tester) async {
    final marked = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NotificationCenterPage(
          loader: () async => items,
          readExecutor: (id) async {
            marked.add(id);
            return true;
          },
          readAllExecutor: () async => 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مركز الإشعارات'), findsOneWidget);
    expect(find.text('1 غير مقروء من أصل 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('notification-item-n1')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('notification-item-n1')),
    );
    await tester.pumpAndSettle();

    expect(marked, <String>['n1']);
    expect(find.text('كل الإشعارات مقروءة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('center can mark all notifications read', (tester) async {
    var markAllCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NotificationCenterPage(
          loader: () async => items,
          readExecutor: (_) async => true,
          readAllExecutor: () async {
            markAllCalls += 1;
            return 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('notification-mark-all-read')),
    );
    await tester.pumpAndSettle();

    expect(markAllCalls, 1);
    expect(find.text('كل الإشعارات مقروءة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
