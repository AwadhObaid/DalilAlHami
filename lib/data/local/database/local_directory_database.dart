import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../../../core/constants/app_catalog.dart';
import '../../../models/account_business.dart';
import '../../../models/account_profile.dart';
import '../../../models/business.dart';
import '../../../models/business_gallery_image.dart';
import '../../../models/directory_advertisement.dart';
import '../../../models/service_category.dart';
import '../../local_directory_store.dart';
import '../../sync/directory_sync_delta.dart';
import '../../sync_queue/sync_conflict.dart';
import '../../sync_queue/sync_queue_item.dart';
import 'directory_database_platform.dart';

class DirectoryCacheSnapshot {
  const DirectoryCacheSnapshot({
    required this.categories,
    required this.businesses,
    required this.advertisements,
    this.advertisementItems = const <DirectoryAdvertisement>[],
    required this.isInitialized,
    required this.isSeedData,
    required this.lastSyncVersion,
    this.lastSyncedAt,
  });

  final List<ServiceCategory> categories;
  final List<Business> businesses;
  final List<String> advertisements;
  final List<DirectoryAdvertisement> advertisementItems;
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

  static const int schemaVersion = 10;

  static const String _categoriesTable = 'directory_categories';
  static const String _businessesTable = 'directory_businesses';
  static const String _advertisementsTable = 'directory_advertisements';
  static const String _metadataTable = 'directory_metadata';
  static const String _syncQueueTable = 'directory_sync_queue';
  static const String _syncConflictsTable = 'directory_sync_conflicts';
  static const String _accountProfilesTable = 'account_profiles_cache';
  static const String _accountBusinessesTable = 'account_businesses_cache';

  static const String _initializedKey = 'cache_initialized';
  static const String _cacheKindKey = 'cache_kind';
  static const String _lastSyncedAtKey = 'last_synced_at';
  static const String _lastSyncVersionKey = 'last_sync_version';

  final DatabaseFactory? _providedFactory;
  final String? _providedPath;

  Database? _database;
  Future<Database>? _openingDatabase;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    if (existing != null) {
      _database = null;
    }

    final activeOpening = _openingDatabase;
    if (activeOpening != null) {
      final opened = await activeOpening;
      if (opened.isOpen) {
        return opened;
      }
      _openingDatabase = null;
    }

    final opening = _openDatabase();
    _openingDatabase = opening;
    try {
      final opened = await opening;
      if (!opened.isOpen) {
        throw StateError('SQLite returned a closed database connection.');
      }
      _database = opened;
      return opened;
    } finally {
      if (identical(_openingDatabase, opening)) {
        _openingDatabase = null;
      }
    }
  }

  Future<Database> _openDatabase() async {
    final factory = _providedFactory ?? await resolveDirectoryDatabaseFactory();
    final path = _providedPath ?? await resolveDirectoryDatabasePath(factory);

    return factory.openDatabase(
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
        latitude REAL,
        longitude REAL,
        gallery_json TEXT NOT NULL DEFAULT '[]',
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
        business_id TEXT,
        placement TEXT NOT NULL DEFAULT 'home_top',
        image_path TEXT,
        compact_image_path TEXT,
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
    await _createSyncConflictSchema(database);
    await _createAccountCacheSchema(database);
  }

  Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    await _ensureCoreDirectoryTables(database);
    await _createAccountCacheSchema(database);

    if (oldVersion < 2) {
      await _addColumnIfMissing(
        database,
        tableName: _categoriesTable,
        columnName: 'updated_at',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        database,
        tableName: _categoriesTable,
        columnName: 'deleted_at',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        database,
        tableName: _categoriesTable,
        columnName: 'sync_version',
        definition: 'INTEGER NOT NULL DEFAULT 0',
      );

      await _addColumnIfMissing(
        database,
        tableName: _businessesTable,
        columnName: 'updated_at',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        database,
        tableName: _businessesTable,
        columnName: 'deleted_at',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        database,
        tableName: _businessesTable,
        columnName: 'sync_version',
        definition: 'INTEGER NOT NULL DEFAULT 0',
      );

      await _addColumnIfMissing(
        database,
        tableName: _advertisementsTable,
        columnName: 'image_path',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        database,
        tableName: _advertisementsTable,
        columnName: 'target_url',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        database,
        tableName: _advertisementsTable,
        columnName: 'is_active',
        definition: 'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(
        database,
        tableName: _advertisementsTable,
        columnName: 'starts_at',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        database,
        tableName: _advertisementsTable,
        columnName: 'ends_at',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        database,
        tableName: _advertisementsTable,
        columnName: 'updated_at',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        database,
        tableName: _advertisementsTable,
        columnName: 'deleted_at',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        database,
        tableName: _advertisementsTable,
        columnName: 'sync_version',
        definition: 'INTEGER NOT NULL DEFAULT 0',
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

    if (oldVersion < 5) {
      await _migrateAccountBusinessesToMultiple(database);
    }

    if (oldVersion >= 5 && oldVersion < 6) {
      await _addColumnIfMissing(
        database,
        tableName: _accountBusinessesTable,
        columnName: 'sync_version',
        definition: 'INTEGER NOT NULL DEFAULT 0',
      );
    }

    if (oldVersion < 6) {
      await _createSyncConflictSchema(database);
    }

    if (oldVersion < 7) {
      await _ensureAdvertisementSchemaV7(database);
    }

    if (oldVersion < 8) {
      await _addColumnIfMissing(
        database,
        tableName: _advertisementsTable,
        columnName: 'compact_image_path',
        definition: 'TEXT',
      );
    }

    if (oldVersion < 9) {
      await _addColumnIfMissing(
        database,
        tableName: _businessesTable,
        columnName: 'gallery_json',
        definition: "TEXT NOT NULL DEFAULT '[]'",
      );
      await _addColumnIfMissing(
        database,
        tableName: _accountBusinessesTable,
        columnName: 'gallery_json',
        definition: "TEXT NOT NULL DEFAULT '[]'",
      );
      await _addColumnIfMissing(
        database,
        tableName: _accountBusinessesTable,
        columnName: 'local_gallery_json',
        definition: "TEXT NOT NULL DEFAULT '[]'",
      );
    }

    if (oldVersion < 10) {
      await _addColumnIfMissing(
        database,
        tableName: _businessesTable,
        columnName: 'latitude',
        definition: 'REAL',
      );
      await _addColumnIfMissing(
        database,
        tableName: _businessesTable,
        columnName: 'longitude',
        definition: 'REAL',
      );
      await _addColumnIfMissing(
        database,
        tableName: _accountBusinessesTable,
        columnName: 'latitude',
        definition: 'REAL',
      );
      await _addColumnIfMissing(
        database,
        tableName: _accountBusinessesTable,
        columnName: 'longitude',
        definition: 'REAL',
      );
    }

    await database.execute(
      '''
      CREATE INDEX IF NOT EXISTS directory_businesses_category_id_idx
      ON $_businessesTable(category_id)
      ''',
    );
    await database.execute(
      '''
      CREATE INDEX IF NOT EXISTS directory_businesses_category_name_idx
      ON $_businessesTable(category_name)
      ''',
    );
  }

  static Future<void> _ensureCoreDirectoryTables(
    DatabaseExecutor database,
  ) async {
    await database.execute(
      '''
      CREATE TABLE IF NOT EXISTS $_categoriesTable (
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
      CREATE TABLE IF NOT EXISTS $_businessesTable (
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
        latitude REAL,
        longitude REAL,
        gallery_json TEXT NOT NULL DEFAULT '[]',
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
      CREATE TABLE IF NOT EXISTS $_advertisementsTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        business_id TEXT,
        placement TEXT NOT NULL DEFAULT 'home_top',
        image_path TEXT,
        compact_image_path TEXT,
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
      CREATE TABLE IF NOT EXISTS $_metadataTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
      ''',
    );
  }

  static Future<void> _ensureAdvertisementSchemaV7(
    DatabaseExecutor database,
  ) async {
    final tableExists = await _tableExists(
      database,
      _advertisementsTable,
    );

    if (!tableExists) {
      await database.execute(
        '''
        CREATE TABLE $_advertisementsTable (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          business_id TEXT,
          placement TEXT NOT NULL DEFAULT 'home_top',
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
      return;
    }

    await _addColumnIfMissing(
      database,
      tableName: _advertisementsTable,
      columnName: 'business_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      database,
      tableName: _advertisementsTable,
      columnName: 'placement',
      definition: "TEXT NOT NULL DEFAULT 'home_top'",
    );
    await _addColumnIfMissing(
      database,
      tableName: _advertisementsTable,
      columnName: 'compact_image_path',
      definition: 'TEXT',
    );
  }

  static Future<void> _addColumnIfMissing(
    DatabaseExecutor database, {
    required String tableName,
    required String columnName,
    required String definition,
  }) async {
    if (await _columnExists(database, tableName, columnName)) {
      return;
    }

    await database.execute(
      'ALTER TABLE $tableName ADD COLUMN $columnName $definition',
    );
  }

  static Future<bool> _tableExists(
    DatabaseExecutor database,
    String tableName,
  ) async {
    final rows = await database.rawQuery(
      '''
      SELECT 1
      FROM sqlite_master
      WHERE type = 'table' AND name = ?
      LIMIT 1
      ''',
      [tableName],
    );

    return rows.isNotEmpty;
  }

  static Future<bool> _columnExists(
    DatabaseExecutor database,
    String tableName,
    String columnName,
  ) async {
    if (!await _tableExists(database, tableName)) {
      return false;
    }

    final rows = await database.rawQuery(
      'PRAGMA table_info($tableName)',
    );

    return rows.any((row) => row['name']?.toString() == columnName);
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

  static Future<void> _createSyncConflictSchema(
    DatabaseExecutor database,
  ) async {
    await database.execute(
      '''
      CREATE TABLE IF NOT EXISTS $_syncConflictsTable (
        id TEXT PRIMARY KEY,
        operation_id TEXT NOT NULL UNIQUE,
        user_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        local_payload_json TEXT NOT NULL DEFAULT '{}',
        server_snapshot_json TEXT NOT NULL DEFAULT '{}',
        expected_sync_version INTEGER NOT NULL DEFAULT 0,
        server_sync_version INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending'
          CHECK (status IN (
            'pending',
            'resolved_keep_local',
            'resolved_use_server'
          )),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        resolved_at TEXT,
        resolution_operation_id TEXT,
        CHECK (entity_type IN ('business')),
        CHECK (operation_type IN (
          'create',
          'update',
          'delete',
          'submit_for_review'
        ))
      )
      ''',
    );

    await database.execute(
      '''
      CREATE INDEX IF NOT EXISTS directory_sync_conflicts_user_status_idx
      ON $_syncConflictsTable(user_id, status, created_at DESC)
      ''',
    );
  }

  static Future<void> _migrateAccountBusinessesToMultiple(
    DatabaseExecutor database,
  ) async {
    const previousTable = 'account_businesses_cache_single_owner_v4';

    await database.execute('DROP TABLE IF EXISTS $previousTable');
    await database.execute(
      'ALTER TABLE $_accountBusinessesTable RENAME TO $previousTable',
    );
    await database.execute(
      '''
      CREATE TABLE $_accountBusinessesTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        category_id TEXT NOT NULL DEFAULT '',
        category_name TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        whatsapp TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT 'الحامي',
        logo_url TEXT,
        local_logo_path TEXT,
        gallery_json TEXT NOT NULL DEFAULT '[]',
        local_gallery_json TEXT NOT NULL DEFAULT '[]',
        latitude REAL,
        longitude REAL,
        status TEXT NOT NULL DEFAULT 'draft',
        rejection_reason TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sync_version INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
      ''',
    );
    await database.execute(
      '''
      INSERT OR REPLACE INTO $_accountBusinessesTable (
        id, user_id, category_id, category_name, name, description,
        phone, whatsapp, address, logo_url, local_logo_path, status,
        rejection_reason, is_active, sync_version, updated_at
      )
      SELECT
        id, user_id, category_id, category_name, name, description,
        phone, whatsapp, address, logo_url, local_logo_path, status,
        rejection_reason, is_active, 0, updated_at
      FROM $previousTable
      ''',
    );
    await database.execute('DROP TABLE $previousTable');
    await database.execute(
      '''
      CREATE INDEX IF NOT EXISTS account_businesses_cache_user_idx
      ON $_accountBusinessesTable(user_id, updated_at DESC)
      ''',
    );
  }

  static Future<void> _createAccountCacheSchema(
    DatabaseExecutor database,
  ) async {
    await database.execute(
      '''
      CREATE TABLE IF NOT EXISTS $_accountProfilesTable (
        user_id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL DEFAULT '',
        email TEXT,
        phone TEXT NOT NULL DEFAULT '',
        avatar_url TEXT,
        role TEXT NOT NULL DEFAULT 'user',
        is_active INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
      ''',
    );

    await database.execute(
      '''
      CREATE TABLE IF NOT EXISTS $_accountBusinessesTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        category_id TEXT NOT NULL DEFAULT '',
        category_name TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        whatsapp TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT 'الحامي',
        logo_url TEXT,
        local_logo_path TEXT,
        gallery_json TEXT NOT NULL DEFAULT '[]',
        local_gallery_json TEXT NOT NULL DEFAULT '[]',
        latitude REAL,
        longitude REAL,
        status TEXT NOT NULL DEFAULT 'draft',
        rejection_reason TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sync_version INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
      ''',
    );

    await database.execute(
      '''
      CREATE INDEX IF NOT EXISTS account_businesses_cache_user_idx
      ON $_accountBusinessesTable(user_id, updated_at DESC)
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
    final advertisementItems = advertisementRows
        .map(_advertisementFromRow)
        .where((advertisement) => advertisement.isVisibleAt(now))
        .toList(growable: false);
    final advertisements = advertisementItems
        .where((advertisement) => advertisement.placement == 'home_top')
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
      advertisementItems: advertisementItems,
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

  Future<void> upsertAccountProfile(
    AccountProfile profile, {
    DateTime? updatedAt,
  }) async {
    final database = await this.database;
    await database.insert(
      _accountProfilesTable,
      <String, Object?>{
        'user_id': profile.id,
        'full_name': profile.fullName,
        'email': profile.email,
        'phone': profile.phone,
        'avatar_url': profile.avatarUrl,
        'role': profile.role,
        'is_active': profile.isActive ? 1 : 0,
        'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AccountProfile?> readAccountProfile({
    required String userId,
  }) async {
    final database = await this.database;
    final rows = await database.query(
      _accountProfilesTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    return AccountProfile(
      id: row['user_id']?.toString() ?? '',
      fullName: row['full_name']?.toString() ?? '',
      phone: row['phone']?.toString() ?? '',
      role: row['role']?.toString() ?? 'user',
      isActive: _readBoolean(row['is_active']),
      email: _nullableString(row['email']),
      avatarUrl: _nullableString(row['avatar_url']),
    );
  }

  Future<void> upsertOwnedBusinessCache(
    AccountBusiness business, {
    DateTime? updatedAt,
  }) async {
    final database = await this.database;
    await database.insert(
      _accountBusinessesTable,
      <String, Object?>{
        'id': business.id,
        'user_id': business.ownerId,
        'category_id': business.categoryId,
        'category_name': business.categoryName,
        'name': business.name,
        'description': business.description,
        'phone': business.phone,
        'whatsapp': business.whatsapp,
        'address': business.address,
        'logo_url': business.logoUrl,
        'local_logo_path': business.localLogoPath,
        'gallery_json': jsonEncode(
          business.galleryImages.map((image) => image.toMap()).toList(),
        ),
        'local_gallery_json': jsonEncode(business.localGalleryPaths),
        'latitude': business.latitude,
        'longitude': business.longitude,
        'status': business.status,
        'rejection_reason': business.rejectionReason,
        'is_active': business.isActive ? 1 : 0,
        'sync_version': business.syncVersion,
        'updated_at': (updatedAt ?? business.updatedAt ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AccountBusiness>> readOwnedBusinessesCache({
    required String userId,
  }) async {
    final database = await this.database;
    final rows = await database.query(
      _accountBusinessesTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
    );

    return rows.map(_accountBusinessFromRow).toList(growable: false);
  }

  Future<AccountBusiness?> readOwnedBusinessCache({
    required String userId,
  }) async {
    final businesses = await readOwnedBusinessesCache(userId: userId);
    return businesses.isEmpty ? null : businesses.first;
  }

  Future<AccountBusiness?> readOwnedBusinessCacheById({
    required String userId,
    required String businessId,
  }) async {
    final database = await this.database;
    final rows = await database.query(
      _accountBusinessesTable,
      where: 'user_id = ? AND id = ?',
      whereArgs: <Object?>[userId, businessId],
      limit: 1,
    );
    return rows.isEmpty ? null : _accountBusinessFromRow(rows.first);
  }

  static AccountBusiness _accountBusinessFromRow(
    Map<String, Object?> row,
  ) {
    return AccountBusiness(
      id: row['id']?.toString() ?? '',
      ownerId: row['user_id']?.toString() ?? '',
      categoryId: row['category_id']?.toString() ?? '',
      categoryName: row['category_name']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      phone: row['phone']?.toString() ?? '',
      whatsapp: row['whatsapp']?.toString() ?? '',
      address: row['address']?.toString() ?? 'الحامي',
      status: row['status']?.toString() ?? 'draft',
      isActive: _readBoolean(row['is_active']),
      logoUrl: _nullableString(row['logo_url']),
      localLogoPath: _nullableString(row['local_logo_path']),
      galleryImages: _galleryImagesFromJson(row['gallery_json']),
      localGalleryPaths: _stringListFromJson(row['local_gallery_json']),
      latitude: _readDouble(row['latitude']),
      longitude: _readDouble(row['longitude']),
      rejectionReason: _nullableString(row['rejection_reason']),
      syncVersion: _readInteger(row['sync_version']),
      updatedAt: DateTime.tryParse(
        row['updated_at']?.toString() ?? '',
      )?.toUtc(),
    );
  }

  Future<int> deleteOwnedBusinessCache({
    required String userId,
    String? businessId,
  }) async {
    final database = await this.database;
    if (businessId == null || businessId.trim().isEmpty) {
      return database.delete(
        _accountBusinessesTable,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    }

    return database.delete(
      _accountBusinessesTable,
      where: 'user_id = ? AND id = ?',
      whereArgs: [userId, businessId],
    );
  }

  /// Removes stale local mutations superseded by an authoritative delete tombstone.
  ///
  /// A create can be locally marked failed after the server already accepted it
  /// when a later post-create step fails. If that entity is then deleted
  /// successfully, retrying the stale create replays the old server receipt and
  /// targets a business that no longer exists. A completed delete is therefore
  /// authoritative for stale pending/failed creates of the same entity id.
  Future<int> purgeSupersededBusinessSyncOperations({
    required String userId,
    String? entityId,
  }) async {
    final database = await this.database;
    final normalizedEntityId = entityId?.trim();
    final hasEntityFilter =
        normalizedEntityId != null && normalizedEntityId.isNotEmpty;
    final arguments = <Object?>[
      userId,
      if (hasEntityFilter) normalizedEntityId,
    ];

    await database.rawDelete(
      '''
      DELETE FROM $_syncConflictsTable
      WHERE rowid IN (
        SELECT conflict.rowid
        FROM $_syncConflictsTable AS conflict
        WHERE conflict.user_id = ?
          ${hasEntityFilter ? 'AND conflict.entity_id = ?' : ''}
          AND conflict.status = 'pending'
          AND EXISTS (
            SELECT 1
            FROM $_syncQueueTable AS deletion
            WHERE deletion.user_id = conflict.user_id
              AND deletion.entity_type = 'business'
              AND deletion.entity_id = conflict.entity_id
              AND deletion.operation_type = 'delete'
              AND deletion.status IN ('pending', 'processing', 'completed')
          )
      )
      ''',
      arguments,
    );

    final purgedCreateCount = await database.rawDelete(
      '''
      DELETE FROM $_syncQueueTable
      WHERE rowid IN (
        SELECT candidate.rowid
        FROM $_syncQueueTable AS candidate
        WHERE candidate.user_id = ?
          ${hasEntityFilter ? 'AND candidate.entity_id = ?' : ''}
          AND candidate.entity_type = 'business'
          AND candidate.operation_type = 'create'
          AND candidate.status IN ('pending', 'failed')
          AND EXISTS (
            SELECT 1
            FROM $_syncQueueTable AS deletion
            WHERE deletion.user_id = candidate.user_id
              AND deletion.entity_type = 'business'
              AND deletion.entity_id = candidate.entity_id
              AND deletion.operation_type = 'delete'
              AND deletion.status = 'completed'
          )
      )
      ''',
      arguments,
    );

    final purgedMutationCount = await database.rawDelete(
      '''
      DELETE FROM $_syncQueueTable
      WHERE rowid IN (
        SELECT candidate.rowid
        FROM $_syncQueueTable AS candidate
        WHERE candidate.user_id = ?
          ${hasEntityFilter ? 'AND candidate.entity_id = ?' : ''}
          AND candidate.entity_type = 'business'
          AND candidate.operation_type IN ('update', 'submit_for_review')
          AND candidate.status IN ('pending', 'failed')
          AND EXISTS (
            SELECT 1
            FROM $_syncQueueTable AS deletion
            WHERE deletion.user_id = candidate.user_id
              AND deletion.entity_type = 'business'
              AND deletion.entity_id = candidate.entity_id
              AND deletion.operation_type = 'delete'
              AND deletion.status IN ('pending', 'processing', 'completed')
          )
      )
      ''',
      arguments,
    );

    return purgedCreateCount + purgedMutationCount;
  }

  Future<SyncQueueItem> enqueueSyncOperation(
    SyncQueueEnqueueRequest request,
  ) async {
    request.validate();
    final database = await this.database;

    return database.transaction((transaction) async {
      if (request.entityType == SyncQueueEntityType.business &&
          request.operationType == SyncQueueOperationType.deleteEntity &&
          request.entityId != null &&
          request.entityId!.trim().isNotEmpty) {
        final businessId = request.entityId!.trim();

        await transaction.delete(
          _syncConflictsTable,
          where: '''
            user_id = ?
            AND entity_type = 'business'
            AND entity_id = ?
            AND status = 'pending'
          ''',
          whereArgs: <Object?>[request.userId, businessId],
        );

        await transaction.delete(
          _syncQueueTable,
          where: '''
            user_id = ?
            AND entity_type = 'business'
            AND entity_id = ?
            AND operation_type IN ('update', 'submit_for_review')
            AND status IN ('pending', 'failed')
          ''',
          whereArgs: <Object?>[request.userId, businessId],
        );
      }
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
    await purgeSupersededBusinessSyncOperations(userId: userId);
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
    await purgeSupersededBusinessSyncOperations(userId: userId);
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
    Map<String, dynamic>? remoteResult,
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
          last_error = ?,
          remote_result_json = ?
        WHERE id = ? AND user_id = ? AND status = ?
        ''',
        [
          SyncQueueStatus.failed.databaseValue,
          utcFailedAt.toIso8601String(),
          safeMessage,
          remoteResult == null ? null : jsonEncode(remoteResult),
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

  Future<void> upsertSyncConflict(SyncConflict conflict) async {
    final database = await this.database;
    await database.insert(
      _syncConflictsTable,
      conflict.toDatabaseRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncConflict>> readSyncConflicts({
    required String userId,
    bool pendingOnly = false,
    int limit = 100,
  }) async {
    final database = await this.database;
    final rows = await database.query(
      _syncConflictsTable,
      where: pendingOnly ? "user_id = ? AND status = 'pending'" : 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(SyncConflict.fromDatabaseRow).toList(growable: false);
  }

  Future<SyncConflict?> readSyncConflictByOperation({
    required String userId,
    required String operationId,
  }) async {
    final database = await this.database;
    final rows = await database.query(
      _syncConflictsTable,
      where: 'user_id = ? AND operation_id = ?',
      whereArgs: <Object?>[userId, operationId],
      limit: 1,
    );
    return rows.isEmpty ? null : SyncConflict.fromDatabaseRow(rows.first);
  }

  Future<void> resolveSyncConflict({
    required SyncConflict conflict,
    required SyncConflictStatus resolution,
    required DateTime resolvedAt,
    String? resolutionOperationId,
  }) async {
    if (resolution == SyncConflictStatus.pending) {
      throw ArgumentError.value(
        resolution,
        'resolution',
        'A resolved conflict cannot remain pending.',
      );
    }

    final database = await this.database;
    final utcResolvedAt = resolvedAt.toUtc();
    await database.transaction((transaction) async {
      await transaction.update(
        _syncConflictsTable,
        <String, Object?>{
          'status': resolution.databaseValue,
          'updated_at': utcResolvedAt.toIso8601String(),
          'resolved_at': utcResolvedAt.toIso8601String(),
          'resolution_operation_id': resolutionOperationId,
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: <Object?>[conflict.id, conflict.userId],
      );

      final operation = await _readSyncOperationById(
        transaction,
        conflict.operationId,
        userId: conflict.userId,
      );
      if (operation != null) {
        final result = <String, dynamic>{
          ...?operation.remoteResult,
          'conflict_resolution': resolution.databaseValue,
          if (resolutionOperationId != null)
            'resolution_operation_id': resolutionOperationId,
        };
        final completed = operation.copyWith(
          status: SyncQueueStatus.completed,
          updatedAt: utcResolvedAt,
          nextAttemptAt: null,
          completedAt: utcResolvedAt,
          lastError: null,
          remoteResult: result,
        );
        await transaction.update(
          _syncQueueTable,
          completed.toDatabaseRow(),
          where: 'id = ? AND user_id = ?',
          whereArgs: <Object?>[operation.id, conflict.userId],
        );
      }
    });
  }

  Future<void> applySuccessfulBusinessSync({
    required String userId,
    required String entityId,
    required SyncQueueOperationType operationType,
    required Map<String, dynamic>? serverSnapshot,
    required int? serverSyncVersion,
  }) async {
    if (operationType == SyncQueueOperationType.deleteEntity) {
      await deleteOwnedBusinessCache(
        userId: userId,
        businessId: entityId,
      );
      return;
    }

    if (serverSnapshot == null) {
      return;
    }

    final business = AccountBusiness.fromMap(
      <String, dynamic>{
        ...serverSnapshot,
        'id': entityId,
        'owner_id': userId,
        if (serverSyncVersion != null) 'sync_version': serverSyncVersion,
      },
    );
    await upsertOwnedBusinessCache(business);
  }

  Future<void> applyServerConflictSnapshot(
    SyncConflict conflict,
  ) async {
    if (conflict.entityType != SyncQueueEntityType.business) {
      return;
    }

    final snapshot = conflict.serverSnapshot;
    final business = AccountBusiness.fromMap(
      <String, dynamic>{
        ...snapshot,
        'id': conflict.entityId,
        'owner_id': conflict.userId,
        'sync_version': conflict.serverSyncVersion,
      },
    );
    await upsertOwnedBusinessCache(business);
  }

  Future<int> retryFailedSyncOperations({
    required String userId,
    String? operationId,
    DateTime? now,
  }) async {
    await purgeSupersededBusinessSyncOperations(userId: userId);
    final database = await this.database;
    final utcNow = (now ?? DateTime.now()).toUtc();
    final where = StringBuffer("user_id = ? AND status = 'failed'");
    final whereArgs = <Object?>[userId];

    if (operationId != null && operationId.trim().isNotEmpty) {
      where.write(' AND id = ?');
      whereArgs.add(operationId);
    }

    return database.update(
      _syncQueueTable,
      {
        'status': SyncQueueStatus.pending.databaseValue,
        'attempt_count': 0,
        'updated_at': utcNow.toIso8601String(),
        'next_attempt_at': utcNow.toIso8601String(),
        'last_attempt_at': null,
        'completed_at': null,
        'last_error': null,
      },
      where: where.toString(),
      whereArgs: whereArgs,
    );
  }

  Future<SyncQueueSummary> readSyncQueueSummary({
    required String userId,
  }) async {
    await purgeSupersededBusinessSyncOperations(userId: userId);
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
    _openingDatabase = null;
    if (database != null && database.isOpen) {
      await database.close();
    }
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
      'latitude': business.latitude,
      'longitude': business.longitude,
      'gallery_json': jsonEncode(
        business.galleryImages.map((image) => image.toMap()).toList(),
      ),
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
      latitude: _readDouble(row['latitude']),
      longitude: _readDouble(row['longitude']),
      galleryImages: _galleryImagesFromJson(row['gallery_json']),
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
      'business_id': advertisement.businessId,
      'placement': advertisement.placement,
      'image_path': advertisement.imagePath,
      'compact_image_path': advertisement.compactImagePath,
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
      businessId: _nullableString(row['business_id']),
      placement: row['placement']?.toString() ?? 'home_top',
      imagePath: _nullableString(row['image_path']),
      compactImagePath: _nullableString(row['compact_image_path']),
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

  static double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  static int _readInteger(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<BusinessGalleryImage> _galleryImagesFromJson(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return const <BusinessGalleryImage>[];
    }
    try {
      return BusinessGalleryImage.readList(jsonDecode(text));
    } catch (_) {
      return const <BusinessGalleryImage>[];
    }
  }

  static List<String> _stringListFromJson(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return const <String>[];
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) {
        return const <String>[];
      }
      return List<String>.unmodifiable(
        decoded
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty),
      );
    } catch (_) {
      return const <String>[];
    }
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
