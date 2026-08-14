import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalDirectoryDatabase database;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    database = LocalDirectoryDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('ينشئ طابور SQLite ويمنع تكرار المفتاح نفسه', () async {
    await database.initializeWithSeedData();
    final createdAt = DateTime.utc(2026, 8, 4, 1);
    final request = SyncQueueEnqueueRequest(
      userId: 'user-001',
      operationId: 'operation-001',
      deduplicationKey: 'business:update:001:version-1',
      entityType: SyncQueueEntityType.business,
      entityId: 'business-001',
      operationType: SyncQueueOperationType.update,
      payload: const {'name': 'الاسم الأول'},
      createdAt: createdAt,
    );

    final first = await database.enqueueSyncOperation(request);
    final duplicate = await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-duplicate',
        deduplicationKey: request.deduplicationKey,
        entityType: SyncQueueEntityType.business,
        entityId: 'business-001',
        operationType: SyncQueueOperationType.update,
        payload: const {'name': 'لن تُكرر العملية'},
        createdAt: createdAt,
      ),
    );

    final summary = await database.readSyncQueueSummary(userId: 'user-001');
    expect(first.id, 'operation-001');
    expect(duplicate.id, 'operation-001');
    expect(summary.total, 1);
    expect(summary.pending, 1);
  });

  test('يفصل مفاتيح منع التكرار بين المستخدمين', () async {
    await database.initializeWithSeedData();
    final createdAt = DateTime.utc(2026, 8, 4, 1, 30);

    final first = await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-user-001',
        deduplicationKey: 'business:update:shared-key',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-001',
        operationType: SyncQueueOperationType.update,
        payload: const {'name': 'المستخدم الأول'},
        createdAt: createdAt,
      ),
    );
    final second = await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-002',
        operationId: 'operation-user-002',
        deduplicationKey: 'business:update:shared-key',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-002',
        operationType: SyncQueueOperationType.update,
        payload: const {'name': 'المستخدم الثاني'},
        createdAt: createdAt,
      ),
    );

    expect(first.id, 'operation-user-001');
    expect(second.id, 'operation-user-002');
    expect(
      (await database.readSyncOperations(userId: 'user-001')),
      hasLength(1),
    );
    expect(
      (await database.readSyncOperations(userId: 'user-002')),
      hasLength(1),
    );
  });

  test('يطالب بعملية مستحقة ثم يسجل فشلها وإعادة محاولتها', () async {
    await database.initializeWithSeedData();
    final now = DateTime.utc(2026, 8, 4, 2);
    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-002',
        deduplicationKey: 'operation-002',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-002',
        operationType: SyncQueueOperationType.submitForReview,
        payload: const {},
        createdAt: now,
      ),
    );

    final due = await database.readDueSyncOperations(
      userId: 'user-001',
      now: now,
    );
    expect(due, hasLength(1));

    final claimed = await database.claimSyncOperation(
      due.single.id,
      userId: 'user-001',
      now: now,
    );
    expect(claimed, isNotNull);
    expect(claimed!.status, SyncQueueStatus.processing);
    expect(claimed.attemptCount, 1);

    final retryAt = now.add(const Duration(seconds: 30));
    await database.markSyncOperationFailed(
      claimed.id,
      userId: 'user-001',
      failedAt: now,
      error: StateError('offline'),
      nextAttemptAt: retryAt,
    );

    expect(
      await database.readDueSyncOperations(
        userId: 'user-001',
        now: now.add(const Duration(seconds: 20)),
      ),
      isEmpty,
    );
    expect(
      await database.readDueSyncOperations(
        userId: 'user-001',
        now: retryAt,
      ),
      hasLength(1),
    );
  });

  test('يسجل نجاح العملية ويحفظ نتيجة الخادم', () async {
    await database.initializeWithSeedData();
    final now = DateTime.utc(2026, 8, 4, 3);
    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-003',
        deduplicationKey: 'operation-003',
        entityType: SyncQueueEntityType.business,
        operationType: SyncQueueOperationType.create,
        payload: const {
          'category_id': 'category-001',
          'name': 'نشاط جديد',
          'phone': '777000333',
        },
        createdAt: now,
      ),
    );

    final claimed = await database.claimSyncOperation(
      'operation-003',
      userId: 'user-001',
      now: now,
    );
    await database.markSyncOperationCompleted(
      claimed!.id,
      userId: 'user-001',
      completedAt: now,
      remoteResult: const {
        'operation_id': 'operation-003',
        'entity_id': 'remote-business-003',
        'remote_status': 'draft',
      },
    );

    final items = await database.readSyncOperations(userId: 'user-001');
    final summary = await database.readSyncQueueSummary(userId: 'user-001');
    expect(items.single.status, SyncQueueStatus.completed);
    expect(
      items.single.remoteResult?['entity_id'],
      'remote-business-003',
    );
    expect(summary.completed, 1);
    expect(summary.actionable, 0);
  });

  test('يستعيد العملية التي انقطع التطبيق أثناء معالجتها', () async {
    await database.initializeWithSeedData();
    final now = DateTime.utc(2026, 8, 4, 4);
    await database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: 'user-001',
        operationId: 'operation-004',
        deduplicationKey: 'operation-004',
        entityType: SyncQueueEntityType.business,
        entityId: 'business-004',
        operationType: SyncQueueOperationType.deleteEntity,
        payload: const {},
        createdAt: now.subtract(const Duration(minutes: 10)),
      ),
    );
    await database.claimSyncOperation(
      'operation-004',
      userId: 'user-001',
      now: now.subtract(const Duration(minutes: 10)),
    );

    final recovered = await database.recoverInterruptedSyncOperations(
      userId: 'user-001',
      now: now,
      processingTimeout: const Duration(minutes: 5),
    );
    final due = await database.readDueSyncOperations(
      userId: 'user-001',
      now: now,
    );

    expect(recovered, 1);
    expect(due, hasLength(1));
    expect(due.single.status, SyncQueueStatus.failed);
  });

  test('يرقي قاعدة SQLite من الإصدار 2 دون فقد البيانات', () async {
    await database.close();

    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'dalil_al_hami_queue_upgrade_',
    );
    final databasePath =
        '${temporaryDirectory.path}${Platform.pathSeparator}directory.db';

    try {
      final versionTwoDatabase = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (database, version) async {
            await database.execute(
              '''
              CREATE TABLE directory_categories (
                id TEXT PRIMARY KEY,
                name_ar TEXT NOT NULL,
                slug TEXT NOT NULL,
                icon_name TEXT NOT NULL,
                sort_order INTEGER NOT NULL DEFAULT 0,
                display_group TEXT NOT NULL,
                image_url TEXT,
                updated_at TEXT,
                deleted_at TEXT,
                sync_version INTEGER NOT NULL DEFAULT 0
              )
              ''',
            );
            await database.execute(
              '''
              CREATE TABLE directory_businesses (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                phone TEXT NOT NULL DEFAULT '',
                whatsapp TEXT NOT NULL DEFAULT '',
                category_name TEXT NOT NULL DEFAULT '',
                place TEXT NOT NULL DEFAULT '',
                details TEXT NOT NULL DEFAULT '',
                image_path TEXT,
                category_id TEXT NOT NULL DEFAULT '',
                category_slug TEXT NOT NULL DEFAULT '',
                logo_url TEXT,
                cover_url TEXT,
                is_featured INTEGER NOT NULL DEFAULT 0,
                is_remote INTEGER NOT NULL DEFAULT 0,
                created_at TEXT,
                updated_at TEXT,
                deleted_at TEXT,
                sync_version INTEGER NOT NULL DEFAULT 0
              )
              ''',
            );
            await database.execute(
              '''
              CREATE TABLE directory_advertisements (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                image_path TEXT,
                target_url TEXT,
                sort_order INTEGER NOT NULL DEFAULT 0,
                is_active INTEGER NOT NULL DEFAULT 1,
                starts_at TEXT,
                ends_at TEXT,
                updated_at TEXT,
                deleted_at TEXT,
                sync_version INTEGER NOT NULL DEFAULT 0
              )
              ''',
            );
            await database.execute(
              '''
              CREATE TABLE directory_metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              )
              ''',
            );
          },
        ),
      );

      await versionTwoDatabase.insert('directory_categories', {
        'id': 'category-before-upgrade',
        'name_ar': 'قسم محفوظ',
        'slug': 'saved-category',
        'icon_name': 'category',
        'sort_order': 1,
        'display_group': 'service',
        'sync_version': 7,
      });
      await versionTwoDatabase.insert('directory_metadata', {
        'key': 'cache_initialized',
        'value': '1',
      });
      await versionTwoDatabase.insert('directory_metadata', {
        'key': 'cache_kind',
        'value': 'remote',
      });
      await versionTwoDatabase.insert('directory_metadata', {
        'key': 'last_synced_at',
        'value': DateTime.utc(2026, 8, 4).toIso8601String(),
      });
      await versionTwoDatabase.insert('directory_metadata', {
        'key': 'last_sync_version',
        'value': '7',
      });
      await versionTwoDatabase.close();

      final upgradedDatabase = LocalDirectoryDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: databasePath,
      );

      try {
        final snapshot = await upgradedDatabase.readSnapshot();
        expect(snapshot.categories, hasLength(1));
        expect(snapshot.categories.single.name, 'قسم محفوظ');
        // Schema 12 intentionally resets only the directory cursor so the
        // next synchronization requests a full snapshot and backfills
        // normalized business contact numbers.
        expect(snapshot.lastSyncVersion, 0);

        await upgradedDatabase.enqueueSyncOperation(
          SyncQueueEnqueueRequest(
            userId: 'user-upgrade',
            operationId: 'operation-after-upgrade',
            deduplicationKey: 'operation-after-upgrade',
            entityType: SyncQueueEntityType.business,
            entityId: 'business-after-upgrade',
            operationType: SyncQueueOperationType.update,
            payload: const {'name': 'بعد الترقية'},
          ),
        );

        final summary = await upgradedDatabase.readSyncQueueSummary(
          userId: 'user-upgrade',
        );
        expect(summary.pending, 1);
      } finally {
        await upgradedDatabase.close();
      }
    } finally {
      await databaseFactoryFfi.deleteDatabase(databasePath);
      await temporaryDirectory.delete(recursive: true);
    }
  });
}
