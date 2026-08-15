import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('upgrades owned-business cache from schema 12 to 13 without data loss',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('dalil_b2_upgrade_');
    final path = '${directory.path}${Platform.pathSeparator}directory.db';

    try {
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 12,
          onCreate: (database, version) async {
            await database.execute('''
              CREATE TABLE account_businesses_cache (
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
            ''');
            await database.insert('account_businesses_cache', <String, Object?>{
              'id': 'legacy-owned',
              'user_id': 'owner',
              'name': 'نشاط محفوظ',
              'phone': '777123456',
              'whatsapp': '777123456',
              'updated_at': '2026-08-14T00:00:00Z',
            });
          },
        ),
      );
      await old.close();

      final upgraded = LocalDirectoryDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: path,
      );
      final raw = await upgraded.database;
      final columns = await raw.rawQuery(
        'PRAGMA table_info(account_businesses_cache)',
      );
      expect(
        columns.any((row) => row['name'] == 'contact_numbers_json'),
        isTrue,
      );

      final business = await upgraded.readOwnedBusinessCacheById(
        userId: 'owner',
        businessId: 'legacy-owned',
      );
      expect(business, isNotNull);
      expect(business!.name, 'نشاط محفوظ');
      expect(business.phone, '777123456');
      expect(business.contactNumbers, isEmpty);

      await upgraded.close();
    } finally {
      if (await databaseFactoryFfi.databaseExists(path)) {
        await databaseFactoryFfi.deleteDatabase(path);
      }
      await directory.delete(recursive: true);
    }
  });
}
