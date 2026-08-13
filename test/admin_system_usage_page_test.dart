import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/admin/admin_system_usage_page.dart';
import 'package:hami_guide/models/admin_system_usage.dart';

void main() {
  testWidgets('admin system usage page renders all three monitoring tabs',
      (tester) async {
    final snapshot = AdminSystemUsageSnapshot(
      capturedAt: DateTime.utc(2026, 8, 13, 13, 43),
      databaseBytes: 13782163,
      storageBytes: 1883446,
      counts: const <String, int>{
        'registered_users': 2,
        'active_users': 2,
        'categories': 25,
        'businesses': 0,
        'advertisements': 1,
        'business_images': 0,
      },
      bucketUsage: const <AdminBucketUsage>[
        AdminBucketUsage(
          bucketId: 'business-media',
          fileCount: 5,
          bytes: 922253,
        ),
        AdminBucketUsage(
          bucketId: 'advertisements',
          fileCount: 4,
          bytes: 719887,
        ),
      ],
      tableUsage: const <AdminTableUsage>[
        AdminTableUsage(
          tableName: 'categories',
          rowCount: 25,
          bytes: 131072,
        ),
      ],
      topFiles: [
        AdminStorageFileUsage(
          bucketId: 'advertisements',
          name: 'admin/ad.jpg',
          bytes: 273804,
          createdAt: DateTime.utc(2026, 8, 12),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminSystemUsagePage(loader: () async => snapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مراقبة النظام والاستهلاك'), findsOneWidget);
    expect(find.text('نظرة عامة'), findsOneWidget);
    expect(find.text('قاعدة البيانات'), findsOneWidget);
    expect(find.text('التخزين'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('admin-usage-database-card')),
      findsOneWidget,
    );

    await tester.tap(find.text('التخزين'));
    await tester.pumpAndSettle();

    expect(find.text('توزيع التخزين حسب Bucket'), findsOneWidget);
    expect(find.text('صور الأنشطة'), findsOneWidget);
    expect(find.text('صور الإعلانات'), findsOneWidget);
    expect(find.text('أكبر الملفات'), findsOneWidget);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.labelColor, Colors.white);
    expect(tabBar.unselectedLabelColor, Colors.white70);
    expect(tabBar.indicatorColor, Colors.white);

    expect(tester.takeException(), isNull);
  });

  testWidgets('usage amount is rendered left-to-right inside Arabic layout',
      (tester) async {
    final snapshot = AdminSystemUsageSnapshot(
      capturedAt: DateTime.utc(2026, 8, 13, 13, 43),
      databaseBytes: 13780000,
      storageBytes: 3600000,
      counts: const <String, int>{},
      bucketUsage: const <AdminBucketUsage>[],
      tableUsage: const <AdminTableUsage>[],
      topFiles: const <AdminStorageFileUsage>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AdminSystemUsagePage(loader: () async => snapshot),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('13.78 MB / 500.00 MB'), findsOneWidget);
    final amount = find.ancestor(
      of: find.text('13.78 MB / 500.00 MB'),
      matching: find.byType(Directionality),
    );
    expect(amount, findsWidgets);
  });
}
