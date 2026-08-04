import 'package:sqflite_common/sqlite_api.dart';

import '../../../core/constants/app_catalog.dart';
import '../../../models/business.dart';
import '../../../models/directory_advertisement.dart';
import '../../../models/service_category.dart';
import '../../local_directory_store.dart';
import '../../sync/directory_sync_delta.dart';
import '../../sync_queue/sync_queue_item.dart';
import 'directory_database_platform.dart';

class DirectoryCacheSnapshot {
  const DirectoryCacheSnapshot({
    required this.categories,
    required this.businesses,
    required this.advertisements,
    required this.isInitialized,
    required this.isSeedData,
    required this.lastSyncVersion,
    this.lastSyncedAt,
  });

  final List<ServiceCategory> categories;
  final List<Business> businesses;
  final List<String> advertisements;
  final bool isInitialized;
  final bool isSeedData;
  final int lastSyncVersion;
  final DateTime? lastSyncedAt;

  bool get hasDirectoryData => categories.isNotEmpty || businesses.isNotEmpty;
}

class LocalDirectoryDatabase {
  LocalDirectoryDatabase({
    DatabaseFactory? databaseFactory,
    String? databasePath,
  })  : _providedFactory = databaseFactory,
        _providedPath = databasePath;

  static final LocalDirectoryDatabase instance = LocalDirectoryDatabase();

  static const int schemaVersion = 3;

  static const String _categoriesTable = 'directory_categories';
  static const String _businessesTable = 'directory_businesses';
  static const String _advertisementsTable = 'directory_advertisements';
  static const String _metadataTable = 'directory_metadata';
  static const String _syncQueueTable = 'directory_sync_queue';

  static const String _initializedKey = 'cache_initialized';
  static const String _cacheKindKey = 'cache_kind';
  static const String _lastSyncedAtKey = 'last_synced_at';
  static const String _lastSyncVersionKey = 'last_sync_version';

  final DatabaseFactory? _providedFactory;
  final String? _providedPath;

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final factory = _providedFactory ?? await resolveDirectoryDatabaseFactory();
    final path = _providedPath ?? await resolveDirectoryDatabasePath(factory);

    final opened = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );

    _database = opened;
    return opened;
  }

  Future<void> _createSchema(
    Database database,
    int version,
  ) async {
    await database.execute(
      '''
      CREATE TABLE $_categoriesTable (
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
      CREATE TABLE $_businessesTable (
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
      CREATE INDEX directory_businesses_category_id_idx
      ON $_businessesTable(category_id)
      ''',
    );

    await database.execute(
      '''
      CREATE INDEX directory_businesses_category_name_idx
      ON $_businessesTable(category_name)
      ''',
    );

    await database.execute(
      '''
      CREATE TABLE $_advertisementsTable (
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
      CREATE TABLE $_metadataTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
      ''',
    );

    await _createSyncQueueSchema(database);
  }

  Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE $_categoriesTable ADD COLUMN updated_at TEXT',
      );
      await database.execute(
        'ALTER TABLE $_categoriesTable ADD COLUMN deleted_at TEXT',
      );
      await database.execute(
        'ALTER TABLE $_categoriesTable '
        'ADD COLUMN sync_version INTEGER NOT NULL DEFAULT 0',
      );

      await database.execute(
        'ALTER TABLE $_businessesTable ADD COLUMN updated_at TEXT',
      );
      await database.execute(
        'ALTER TABLE $_businessesTable ADD COLUMN deleted_at TEXT',
      );
      await database.execute(
        'ALTER TABLE $_businessesTable '
        'ADD COLUMN sync_version INTEGER NOT NULL DEFAULT 0',
      );

      await database.execute(
        'ALTER TABLE $_advertisementsTable ADD COLUMN image_path TEXT',
      );
      await database.execute(
        'ALTER TABLE $_advertisementsTable ADD COLUMN target_url TEXT',
      );
      await database.execute(
        'ALTER TABLE $_advertisementsTable '
        'ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
      );
      await database.execute(
        'ALTER TABLE $_advertisementsTable ADD COLUMN starts_at TEXT',
      );
      await database.execute(
        'ALTER TABLE $_advertisementsTable ADD COLUMN ends_at TEXT',
      );
      await database.execute(
        'ALTER TABLE $_advertisementsTable ADD COLUMN updated_at TEXT',
      );
      await database.execute(
        'ALTER TABLE $_advertisementsTable ADD COLUMN deleted_at TEXT',
      );
      await database.execute(
        'ALTER TABLE $_advertisementsTable '
        'ADD COLUMN sync_version INTEGER NOT NULL DEFAULT 0',
      );

      await _writeMetadata(
        database,
        _lastSyncVersionKey,
        '0',
      );
    }

    if (oldVersion < 3) {
      await _createSyncQueueSchema(database);
    }
  }

  static Future<void> _createSyncQueueSchema(
    DatabaseExecutor database,
  ) async {
    await database.execute(
      '''
      CREATE TABLE IF NOT EXISTS $_syncQueueTable (
        id TEXT PRIMARY KEY,
        deduplication_key TEXT NOT NULL,
        user_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        operation_type TEXT NOT NULL,
        payload_json TEXT NOT NULL DEFAULT '{}',
        status TEXT NOT NULL DEFAULT 'pending'
          CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
        attempt_count INTEGER NOT NULL DEFAULT 0,
        max_attempts INTEGER NOT NULL DEFAULT 5,
        priority INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        next_attempt_at TEXT,
        last_attempt_at TEXT,
        completed_at TEXT,
        last_error TEXT,
        remote_result_json TEXT,
        CHECK (entity_type IN ('business')),
        CHECK (operation_type IN (
          'create',
          'update',
          'delete',
          'submit_for_review'
        )),
        CHECK (attempt_count >= 0),
        CHECK (max_attempts >= 1)
      )
      ''',
    );

    await database.execute(
      '''
      CREATE UNIQUE INDEX IF NOT EXISTS directory_sync_queue_user_dedupe_idx
      ON $_syncQueueTable(user_id, deduplication_key)
      ''',
    );

    await database.execute(
      '''
      CREATE INDEX IF NOT EXISTS directory_sync_queue_due_idx
      ON $_syncQueueTable(user_id, status, next_attempt_at, priority, created_at)
      ''',
    );

    await database.execute(
      '''
      CREATE INDEX IF NOT EXISTS directory_sync_queue_entity_idx
      ON $_syncQueueTable(entity_type, entity_id, created_at)
      ''',
    );
  }

  Future<DirectoryCacheSnapshot> initializeWithSeedData() async {
    final current = await readSnapshot();
    if (current.isInitialized) {
      return current;
    }

    final database = await this.database;
    final localBusinesses =
        LocalDirectoryStore.instance.businesses.toList(growable: false);

    await database.transaction((transaction) async {
      final categoryBatch = transaction.batch();
      for (final category in AppCatalog.allCategories) {
        categoryBatch.insert(
          _categoriesTable,
          _categoryToRow(category),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await categoryBatch.commit(noResult: true);

      final businessBatch = transaction.batch();
      for (final business in localBusinesses) {
        businessBatch.insert(
          _businessesTable,
          _businessToRow(business),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await businessBatch.commit(noResult: true);

      final advertisementBatch = transaction.batch();
      for (var index = 0; index < AppCatalog.advertisements.length; index++) {
        final advertisement = DirectoryAdvertisement(
          id: 'bundled-ad-$index',
          title: AppCatalog.advertisements[index],
          sortOrder: index,
        );
        advertisementBatch.insert(
          _advertisementsTable,
          _advertisementToRow(advertisement),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await advertisementBatch.commit(noResult: true);

      await _writeMetadata(transaction, _initializedKey, '1');
      await _writeMetadata(transaction, _cacheKindKey, 'seed');
      await _writeMetadata(transaction, _lastSyncedAtKey, '');
      await _writeMetadata(transaction, _lastSyncVersionKey, '0');
    });

    return readSnapshot();
  }

  Future<DirectoryCacheSnapshot> readSnapshot() async {
    final database = await this.database;

    final categoryRows = await database.query(
      _categoriesTable,
      orderBy: 'sort_order ASC, name_ar ASC',
    );
    final businessRows = await database.query(
      _businessesTable,
      orderBy: 'is_featured DESC, created_at DESC, name ASC',
    );
    final advertisementRows = await database.query(
      _advertisementsTable,
      orderBy: 'sort_order ASC',
    );
    final metadataRows = await database.query(_metadataTable);

    final metadata = <String, String>{};
    for (final row in metadataRows) {
      final key = row['key']?.toString() ?? '';
      if (key.isEmpty) {
        continue;
      }

      metadata[key] = row['value']?.toString() ?? '';
    }

    final now = DateTime.now().toUtc();
    final advertisements = advertisementRows
        .map(_advertisementFromRow)
        .where((advertisement) => advertisement.isVisibleAt(now))
        .map((advertisement) => advertisement.title)
        .where((title) => title.trim().isNotEmpty)
        .toList(growable: false);

    return DirectoryCacheSnapshot(
      categories: categoryRows
          .map(_categoryFromRow)
          .where((category) => !category.isDeleted)
          .toList(growable: false),
      businesses: businessRows
          .map(_businessFromRow)
          .where((business) => !business.isDeleted)
          .toList(growable: false),
      advertisements: advertisements,
      isInitialized: metadata[_initializedKey] == '1',
      isSeedData: metadata[_cacheKindKey] != 'remote',
      lastSyncVersion: int.tryParse(
            metadata[_lastSyncVersionKey] ?? '',
          ) ??
          0,
      lastSyncedAt: DateTime.tryParse(
        metadata[_lastSyncedAtKey] ?? '',
      ),
    );
  }

  Future<DirectoryCacheSnapshot> applyRemoteChanges({
    required DirectorySyncDelta delta,
    required DateTime syncedAt,
  }) async {
    final database = await this.database;
    final currentVersion = await _readMetadataInteger(
      database,
      _lastSyncVersionKey,
    );

    if (!delta.isFullSnapshot && delta.serverVersion < currentVersion) {
      throw StateError(
        'The incremental sync version cannot move backwards.',
      );
    }

    await database.transaction((transaction) async {
      if (delta.isFullSnapshot) {
        await transaction.delete(_businessesTable);
        await transaction.delete(_categoriesTable);
        await transaction.delete(_advertisementsTable);
      }

      for (final categoryId in delta.deletedCategoryIds) {
        await transaction.delete(
          _businessesTable,
          where: 'category_id = ?',
          whereArgs: [categoryId],
        );
        await transaction.delete(
          _categoriesTable,
          where: 'id = ?',
          whereArgs: [categoryId],
        );
      }

      for (final businessId in delta.deletedBusinessIds) {
        await transaction.delete(
          _businessesTable,
          where: 'id = ?',
          whereArgs: [businessId],
        );
      }

      for (final advertisementId in delta.deletedAdvertisementIds) {
        await transaction.delete(
          _advertisementsTable,
          where: 'id = ?',
          whereArgs: [advertisementId],
        );
      }

      final categoryBatch = transaction.batch();
      for (final category in delta.categories) {
        categoryBatch.insert(
          _categoriesTable,
          _categoryToRow(category),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await categoryBatch.commit(noResult: true);

      final businessBatch = transaction.batch();
      for (final business in delta.businesses) {
        businessBatch.insert(
          _businessesTable,
          _businessToRow(
            business.copyWith(isRemote: true),
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await businessBatch.commit(noResult: true);

      final advertisementBatch = transaction.batch();
      for (final advertisement in delta.advertisements) {
        advertisementBatch.insert(
          _advertisementsTable,
          _advertisementToRow(advertisement),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await advertisementBatch.commit(noResult: true);

      await transaction.rawDelete(
        '''
        DELETE FROM $_businessesTable
        WHERE category_id <> ''
          AND category_id NOT IN (
            SELECT id FROM $_categoriesTable
          )
        ''',
      );

      await _writeMetadata(transaction, _initializedKey, '1');
      await _writeMetadata(transaction, _cacheKindKey, 'remote');
      await _writeMetadata(
        transaction,
        _lastSyncedAtKey,
        syncedAt.toUtc().toIso8601String(),
      );
      await _writeMetadata(
        transaction,
        _lastSyncVersionKey,
        delta.serverVersion.toString(),
      );
    });

    return readSnapshot();
  }

  Future<DirectoryCacheSnapshot> replaceRemoteDirectoryData({
    required List<ServiceCategory> categories,
    required List<Business> businesses,
    required DateTime syncedAt,
  }) async {
    final database = await this.database;

    await database.transaction((transaction) async {
      await transaction.delete(_businessesTable);
      await transaction.delete(_categoriesTable);

      final categoryBatch = transaction.batch();
      for (final category in categories) {
        categoryBatch.insert(
          _categoriesTable,
          _categoryToRow(category),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await categoryBatch.commit(noResult: true);

      final businessBatch = transaction.batch();
      for (final business in businesses) {
        businessBatch.insert(
          _businessesTable,
          _businessToRow(
            business.copyWith(isRemote: true),
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await businessBatch.commit(noResult: true);

      final advertisementCountRows = await transaction.rawQuery(
        'SELECT COUNT(*) AS total FROM $_advertisementsTable',
      );
      final advertisementCount = advertisementCountRows.isEmpty
          ? 0
          : (advertisementCountRows.first['total'] as num?)?.toInt() ?? 0;

      if (advertisementCount == 0) {
        final advertisementBatch = transaction.batch();
        for (var index = 0; index < AppCatalog.advertisements.length; index++) {
          advertisementBatch.insert(
            _advertisementsTable,
            _advertisementToRow(
              DirectoryAdvertisement(
                id: 'bundled-ad-$index',
                title: AppCatalog.advertisements[index],
                sortOrder: index,
              ),
            ),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await advertisementBatch.commit(noResult: true);
      }

      await _writeMetadata(transaction, _initializedKey, '1');
      await _writeMetadata(transaction, _cacheKindKey, 'remote');
      await _writeMetadata(
        transaction,
        _lastSyncedAtKey,
        syncedAt.toUtc().toIso8601String(),
      );
      await _writeMetadata(transaction, _lastSyncVersionKey, '0');
    });

    return readSnapshot();
  }

  Future<SyncQueueItem> enqueueSyncOperation(
    SyncQueueEnqueueRequest request,
  ) async {
    request.validate();
    final database = await this.database;

    return database.transaction((transaction) async {
      final existingRows = await transaction.query(
        _syncQueueTable,
        where: 'user_id = ? AND deduplication_key = ?',
        whereArgs: [request.userId, request.deduplicationKey],
        limit: 1,
      );
      if (existingRows.isNotEmpty) {
        return SyncQueueItem.fromDatabaseRow(existingRows.first);
      }

      final createdAt = request.createdAt.toUtc();
      final item = SyncQueueItem(
        id: request.operationId,
        deduplicationKey: request.deduplicationKey,
        userId: request.userId,
        entityType: request.entityType,
        entityId: request.entityId,
        operationType: request.operationType,
        payload: Map<String, dynamic>.unmodifiable(request.payload),
        status: SyncQueueStatus.pending,
        attemptCount: 0,
        maxAttempts: request.maxAttempts,
        priority: request.priority,
        createdAt: createdAt,
        updatedAt: createdAt,
        nextAttemptAt: createdAt,
      );

      await transaction.insert(
        _syncQueueTable,
        item.toDatabaseRow(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final storedRows = await transaction.query(
        _syncQueueTable,
        where: 'user_id = ? AND deduplication_key = ?',
        whereArgs: [request.userId, request.deduplicationKey],
        limit: 1,
      );
      if (storedRows.isEmpty) {
        throw StateError(
          'The sync queue operation could not be stored.',
        );
      }

      return SyncQueueItem.fromDatabaseRow(storedRows.first);
    });
  }

  Future<List<SyncQueueItem>> readDueSyncOperations({
    required String userId,
    required DateTime now,
    int limit = 20,
  }) async {
    final database = await this.database;
    final rows = await database.query(
      _syncQueueTable,
      where: '''
        user_id = ?
        AND status IN ('pending', 'failed')
        AND attempt_count < max_attempts
        AND (next_attempt_at IS NULL OR next_attempt_at <= ?)
      ''',
      whereArgs: [
        userId,
        now.toUtc().toIso8601String(),
      ],
      orderBy: 'priority DESC, created_at ASC',
      limit: limit,
    );

    return rows.map(SyncQueueItem.fromDatabaseRow).toList(growable: false);
  }

  Future<List<SyncQueueItem>> readSyncOperations({
    required String userId,
    int limit = 100,
  }) async {
    final database = await this.database;
    final rows = await database.query(
      _syncQueueTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows.map(SyncQueueItem.fromDatabaseRow).toList(growable: false);
  }

  Future<SyncQueueItem?> claimSyncOperation(
    String operationId, {
    required String userId,
    required DateTime now,
  }) async {
    final database = await this.database;
    final utcNow = now.toUtc();

    return database.transaction((transaction) async {
      final updated = await transaction.rawUpdate(
        '''
        UPDATE $_syncQueueTable
        SET
          status = 'processing',
          attempt_count = attempt_count + 1,
          last_attempt_at = ?,
          updated_at = ?,
          last_error = NULL
        WHERE id = ?
          AND user_id = ?
          AND status IN ('pending', 'failed')
          AND attempt_count < max_attempts
          AND (next_attempt_at IS NULL OR next_attempt_at <= ?)
        ''',
        [
          utcNow.toIso8601String(),
          utcNow.toIso8601String(),
          operationId,
          userId,
          utcNow.toIso8601String(),
        ],
      );

      if (updated != 1) {
        return null;
      }

      final rows = await transaction.query(
        _syncQueueTable,
        where: 'id = ? AND user_id = ?',
        whereArgs: [operationId, userId],
        limit: 1,
      );
      return rows.isEmpty ? null : SyncQueueItem.fromDatabaseRow(rows.first);
    });
  }

  Future<void> markSyncOperationCompleted(
    String operationId, {
    required String userId,
    required DateTime completedAt,
    required Map<String, dynamic> remoteResult,
  }) async {
    final database = await this.database;
    final utcCompletedAt = completedAt.toUtc();
    final current = await _readSyncOperationById(
      database,
      operationId,
      userId: userId,
    );
    if (current == null) {
      throw StateError('Sync queue operation was not found.');
    }

    final completed = current.copyWith(
      status: SyncQueueStatus.completed,
      updatedAt: utcCompletedAt,
      nextAttemptAt: null,
      completedAt: utcCompletedAt,
      lastError: null,
      remoteResult: Map<String, dynamic>.unmodifiable(remoteResult),
    );

    await database.update(
      _syncQueueTable,
      completed.toDatabaseRow(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [operationId, userId],
    );
  }

  Future<void> markSyncOperationFailed(
    String operationId, {
    required String userId,
    required DateTime failedAt,
    required Object error,
    DateTime? nextAttemptAt,
    bool exhaust = false,
  }) async {
    final database = await this.database;
    final utcFailedAt = failedAt.toUtc();
    final message = error.toString();
    final safeMessage =
        message.length <= 2000 ? message : message.substring(0, 2000);

    if (exhaust) {
      await database.rawUpdate(
        '''
        UPDATE $_syncQueueTable
        SET
          status = ?,
          attempt_count = max_attempts,
          updated_at = ?,
          next_attempt_at = NULL,
          completed_at = NULL,
          last_error = ?
        WHERE id = ? AND user_id = ? AND status = ?
        ''',
        [
          SyncQueueStatus.failed.databaseValue,
          utcFailedAt.toIso8601String(),
          safeMessage,
          operationId,
          userId,
          SyncQueueStatus.processing.databaseValue,
        ],
      );
      return;
    }

    await database.update(
      _syncQueueTable,
      {
        'status': SyncQueueStatus.failed.databaseValue,
        'updated_at': utcFailedAt.toIso8601String(),
        'next_attempt_at': nextAttemptAt?.toUtc().toIso8601String(),
        'completed_at': null,
        'last_error': safeMessage,
      },
      where: 'id = ? AND user_id = ? AND status = ?',
      whereArgs: [
        operationId,
        userId,
        SyncQueueStatus.processing.databaseValue,
      ],
    );
  }

  Future<int> recoverInterruptedSyncOperations({
    required String userId,
    required DateTime now,
    required Duration processingTimeout,
  }) async {
    final database = await this.database;
    final utcNow = now.toUtc();
    final cutoff = utcNow.subtract(processingTimeout);

    return database.rawUpdate(
      '''
      UPDATE $_syncQueueTable
      SET
        status = 'failed',
        updated_at = ?,
        next_attempt_at = ?,
        last_error = 'Recovered after an interrupted queue attempt.'
      WHERE user_id = ?
        AND status = 'processing'
        AND (last_attempt_at IS NULL OR last_attempt_at <= ?)
      ''',
      [
        utcNow.toIso8601String(),
        utcNow.toIso8601String(),
        userId,
        cutoff.toIso8601String(),
      ],
    );
  }

  Future<int> retryFailedSyncOperations({
    required String userId,
    String? operationId,
    DateTime? now,
  }) async {
    final database = await this.database;
    final utcNow = (now ?? DateTime.now()).toUtc();
    final where = StringBuffer(
      "user_id = ? AND status = 'failed' "
      "AND attempt_count < max_attempts",
    );
    final whereArgs = <Object?>[userId];

    if (operationId != null && operationId.trim().isNotEmpty) {
      where.write(' AND id = ?');
      whereArgs.add(operationId);
    }

    return database.update(
      _syncQueueTable,
      {
        'status': SyncQueueStatus.pending.databaseValue,
        'updated_at': utcNow.toIso8601String(),
        'next_attempt_at': utcNow.toIso8601String(),
        'last_error': null,
      },
      where: where.toString(),
      whereArgs: whereArgs,
    );
  }

  Future<SyncQueueSummary> readSyncQueueSummary({
    required String userId,
  }) async {
    final database = await this.database;
    final rows = await database.rawQuery(
      '''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending,
        SUM(CASE WHEN status = 'processing' THEN 1 ELSE 0 END) AS processing,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed,
        SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed,
        SUM(
          CASE
            WHEN status = 'failed' AND attempt_count >= max_attempts
              THEN 1
            ELSE 0
          END
        ) AS exhausted
      FROM $_syncQueueTable
      WHERE user_id = ?
      ''',
      [userId],
    );

    return rows.isEmpty
        ? const SyncQueueSummary()
        : SyncQueueSummary.fromAggregateRow(rows.first);
  }

  Future<int> pruneCompletedSyncOperations({
    required String userId,
    required DateTime olderThan,
  }) async {
    final database = await this.database;
    return database.delete(
      _syncQueueTable,
      where: 'user_id = ? AND status = ? AND completed_at < ?',
      whereArgs: [
        userId,
        SyncQueueStatus.completed.databaseValue,
        olderThan.toUtc().toIso8601String(),
      ],
    );
  }

  Future<SyncQueueItem?> _readSyncOperationById(
    DatabaseExecutor database,
    String operationId, {
    required String userId,
  }) async {
    final rows = await database.query(
      _syncQueueTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [operationId, userId],
      limit: 1,
    );

    return rows.isEmpty ? null : SyncQueueItem.fromDatabaseRow(rows.first);
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }

  Future<int> _readMetadataInteger(
    DatabaseExecutor executor,
    String key,
  ) async {
    final rows = await executor.query(
      _metadataTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) {
      return 0;
    }

    return int.tryParse(rows.first['value']?.toString() ?? '') ?? 0;
  }

  Future<void> _writeMetadata(
    DatabaseExecutor executor,
    String key,
    String value,
  ) async {
    await executor.insert(
      _metadataTable,
      {
        'key': key,
        'value': value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Map<String, Object?> _categoryToRow(
    ServiceCategory category,
  ) {
    return {
      'id': category.id,
      'name_ar': category.name,
      'slug': category.slug,
      'icon_name': category.iconName,
      'sort_order': category.sortOrder,
      'display_group': category.displayGroup.databaseValue,
      'image_url': category.imageUrl,
      'updated_at': category.updatedAt?.toIso8601String(),
      'deleted_at': category.deletedAt?.toIso8601String(),
      'sync_version': category.syncVersion,
    };
  }

  static ServiceCategory _categoryFromRow(
    Map<String, Object?> row,
  ) {
    return ServiceCategory(
      id: row['id']?.toString() ?? '',
      name: row['name_ar']?.toString() ?? '',
      slug: row['slug']?.toString() ?? '',
      iconName: row['icon_name']?.toString() ?? 'category',
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      displayGroup: CategoryDisplayGroup.fromDatabase(
        row['display_group']?.toString(),
      ),
      imageUrl: _nullableString(row['image_url']),
      updatedAt: DateTime.tryParse(
        row['updated_at']?.toString() ?? '',
      ),
      deletedAt: DateTime.tryParse(
        row['deleted_at']?.toString() ?? '',
      ),
      syncVersion: _readInteger(row['sync_version']),
    );
  }

  static Map<String, Object?> _businessToRow(
    Business business,
  ) {
    return {
      'id': business.id,
      'name': business.name,
      'phone': business.phone,
      'whatsapp': business.whatsapp,
      'category_name': business.category,
      'place': business.place,
      'details': business.details,
      'image_path': business.imagePath,
      'category_id': business.categoryId,
      'category_slug': business.categorySlug,
      'logo_url': business.logoUrl,
      'cover_url': business.coverUrl,
      'is_featured': business.isFeatured ? 1 : 0,
      'is_remote': business.isRemote ? 1 : 0,
      'created_at': business.createdAt?.toIso8601String(),
      'updated_at': business.updatedAt?.toIso8601String(),
      'deleted_at': business.deletedAt?.toIso8601String(),
      'sync_version': business.syncVersion,
    };
  }

  static Business _businessFromRow(
    Map<String, Object?> row,
  ) {
    return Business(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      phone: row['phone']?.toString() ?? '',
      whatsapp: row['whatsapp']?.toString() ?? '',
      category: row['category_name']?.toString() ?? '',
      place: row['place']?.toString() ?? '',
      details: row['details']?.toString() ?? '',
      imagePath: _nullableString(row['image_path']),
      categoryId: row['category_id']?.toString() ?? '',
      categorySlug: row['category_slug']?.toString() ?? '',
      logoUrl: _nullableString(row['logo_url']),
      coverUrl: _nullableString(row['cover_url']),
      isFeatured: _readBoolean(row['is_featured']),
      isRemote: _readBoolean(row['is_remote']),
      createdAt: DateTime.tryParse(
        row['created_at']?.toString() ?? '',
      ),
      updatedAt: DateTime.tryParse(
        row['updated_at']?.toString() ?? '',
      ),
      deletedAt: DateTime.tryParse(
        row['deleted_at']?.toString() ?? '',
      ),
      syncVersion: _readInteger(row['sync_version']),
    );
  }

  static Map<String, Object?> _advertisementToRow(
    DirectoryAdvertisement advertisement,
  ) {
    return {
      'id': advertisement.id,
      'title': advertisement.title,
      'image_path': advertisement.imagePath,
      'target_url': advertisement.targetUrl,
      'sort_order': advertisement.sortOrder,
      'is_active': advertisement.isActive ? 1 : 0,
      'starts_at': advertisement.startsAt?.toIso8601String(),
      'ends_at': advertisement.endsAt?.toIso8601String(),
      'updated_at': advertisement.updatedAt?.toIso8601String(),
      'deleted_at': advertisement.deletedAt?.toIso8601String(),
      'sync_version': advertisement.syncVersion,
    };
  }

  static DirectoryAdvertisement _advertisementFromRow(
    Map<String, Object?> row,
  ) {
    return DirectoryAdvertisement(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      imagePath: _nullableString(row['image_path']),
      targetUrl: _nullableString(row['target_url']),
      sortOrder: _readInteger(row['sort_order']),
      isActive: _readBoolean(row['is_active']),
      startsAt: DateTime.tryParse(
        row['starts_at']?.toString() ?? '',
      ),
      endsAt: DateTime.tryParse(
        row['ends_at']?.toString() ?? '',
      ),
      updatedAt: DateTime.tryParse(
        row['updated_at']?.toString() ?? '',
      ),
      deletedAt: DateTime.tryParse(
        row['deleted_at']?.toString() ?? '',
      ),
      syncVersion: _readInteger(row['sync_version']),
    );
  }

  static bool _readBoolean(Object? value) {
    return value == true || value == 1 || value?.toString() == '1';
  }

  static int _readInteger(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
