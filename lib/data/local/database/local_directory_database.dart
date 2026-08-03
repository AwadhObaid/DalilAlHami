import 'package:sqflite_common/sqlite_api.dart';

import '../../../core/constants/app_catalog.dart';
import '../../../models/business.dart';
import '../../../models/service_category.dart';
import '../../local_directory_store.dart';
import 'directory_database_platform.dart';

class DirectoryCacheSnapshot {
  const DirectoryCacheSnapshot({
    required this.categories,
    required this.businesses,
    required this.advertisements,
    required this.isInitialized,
    required this.isSeedData,
    this.lastSyncedAt,
  });

  final List<ServiceCategory> categories;
  final List<Business> businesses;
  final List<String> advertisements;
  final bool isInitialized;
  final bool isSeedData;
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

  static const int schemaVersion = 1;

  static const String _categoriesTable = 'directory_categories';
  static const String _businessesTable = 'directory_businesses';
  static const String _advertisementsTable = 'directory_advertisements';
  static const String _metadataTable = 'directory_metadata';

  static const String _initializedKey = 'cache_initialized';
  static const String _cacheKindKey = 'cache_kind';
  static const String _lastSyncedAtKey = 'last_synced_at';

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
        image_url TEXT
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
        created_at TEXT
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
        sort_order INTEGER NOT NULL DEFAULT 0
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
        advertisementBatch.insert(
          _advertisementsTable,
          {
            'id': 'bundled-ad-$index',
            'title': AppCatalog.advertisements[index],
            'sort_order': index,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await advertisementBatch.commit(noResult: true);

      await _writeMetadata(
        transaction,
        _initializedKey,
        '1',
      );
      await _writeMetadata(
        transaction,
        _cacheKindKey,
        'seed',
      );
      await _writeMetadata(
        transaction,
        _lastSyncedAtKey,
        '',
      );
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

    return DirectoryCacheSnapshot(
      categories: categoryRows.map(_categoryFromRow).toList(growable: false),
      businesses: businessRows.map(_businessFromRow).toList(growable: false),
      advertisements: advertisementRows
          .map((row) => row['title']?.toString() ?? '')
          .where((title) => title.trim().isNotEmpty)
          .toList(growable: false),
      isInitialized: metadata[_initializedKey] == '1',
      isSeedData: metadata[_cacheKindKey] != 'remote',
      lastSyncedAt: DateTime.tryParse(
        metadata[_lastSyncedAtKey] ?? '',
      ),
    );
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
            {
              'id': 'bundled-ad-$index',
              'title': AppCatalog.advertisements[index],
              'sort_order': index,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await advertisementBatch.commit(noResult: true);
      }

      await _writeMetadata(
        transaction,
        _initializedKey,
        '1',
      );
      await _writeMetadata(
        transaction,
        _cacheKindKey,
        'remote',
      );
      await _writeMetadata(
        transaction,
        _lastSyncedAtKey,
        syncedAt.toUtc().toIso8601String(),
      );
    });

    return readSnapshot();
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
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
    );
  }

  static bool _readBoolean(Object? value) {
    return value == true || value == 1 || value?.toString() == '1';
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
