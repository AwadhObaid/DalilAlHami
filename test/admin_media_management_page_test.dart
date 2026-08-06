import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/data/repositories/admin_media_repository.dart';
import 'package:hami_guide/features/admin/admin_media_management_page.dart';
import 'package:hami_guide/models/admin_media_overview.dart';

void main() {
  final overview = AdminMediaOverview(
    profileAvatars: 3,
    categoryImages: 3,
    businessLogos: 7,
    businessCovers: 5,
    galleryImages: 12,
    advertisementImages: 2,
    compactAdvertisementImages: 1,
    draftObjects: 4,
    recentGallery: const <AdminRecentGalleryImage>[],
  );

  testWidgets('يعرض ملخص الوسائط ويفحص الملفات القابلة للتنظيف', (
    tester,
  ) async {
    const candidate = AdminMediaCleanupCandidate(
      bucketId: 'business-media',
      storagePath: 'drafts/user/old.jpg',
      reason: 'expired_draft',
    );
    var scanCalled = false;
    var cleanupCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminMediaManagementPage(
          overviewLoader: () async => overview,
          cleanupLoader: () async {
            scanCalled = true;
            return const <AdminMediaCleanupCandidate>[candidate];
          },
          cleanupExecutor: (items) async {
            cleanupCalled = items.single.storagePath == candidate.storagePath;
            return const AdminMediaCleanupResult(
              deletedCount: 1,
              failed: <AdminMediaCleanupCandidate>[],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('admin-media-summary')),
      findsOneWidget,
    );
    expect(find.text('33 صورة مرتبطة'), findsOneWidget);

    final managementList = find.byKey(
      const PageStorageKey<String>('admin-media-management-list'),
    );
    final scan = find.byKey(
      const ValueKey<String>('admin-media-scan-action'),
    );

    expect(managementList, findsOneWidget);
    await tester.dragUntilVisible(
      scan,
      managementList,
      const Offset(0, -180),
    );
    await tester.ensureVisible(scan);
    await tester.pumpAndSettle();

    expect(scan.hitTestable(), findsOneWidget);
    await tester.tap(scan.hitTestable());
    await tester.pumpAndSettle();

    expect(scanCalled, isTrue);
    expect(
      find.byKey(const ValueKey<String>('admin-media-cleanup-count')),
      findsOneWidget,
    );
    expect(find.text('تم العثور على 1 ملفًا قابلًا للتنظيف.'), findsOneWidget);

    final clean = find.byKey(
      const ValueKey<String>('admin-media-cleanup-action'),
    );
    await tester.ensureVisible(clean);
    await tester.pumpAndSettle();

    expect(clean.hitTestable(), findsOneWidget);
    await tester.tap(clean.hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('admin-media-cleanup-confirm')),
    );
    await tester.pumpAndSettle();

    expect(cleanupCalled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('إدارة الوسائط تتحمل شاشة ضيقة وخطًا مكبرًا', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 720),
            textScaler: TextScaler.linear(1.3),
          ),
          child: AdminMediaManagementPage(
            overviewLoader: () async => overview,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إدارة الصور والوسائط'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
