import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('upgrades SQLite v10 to v12 without losing existing businesses',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('dalil_contact_upgrade_');
    final path = '${directory.path}${Platform.pathSeparator}directory.db';

    try {
      final oldDatabase = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 10,
          onCreate: (database, version) async {
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
            await database.insert('directory_businesses', <String, Object?>{
              'id': 'legacy-business',
              'name': 'نشاط محفوظ قبل الترقية',
              'phone': '777000111',
              'category_name': 'خدمات',
              'place': 'الحامي',
            });
          },
        ),
      );
      await oldDatabase.close();

      final upgraded = LocalDirectoryDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: path,
      );
      final rawDatabase = await upgraded.database;

      final columns =
          await rawDatabase.rawQuery('PRAGMA table_info(directory_businesses)');
      expect(
          columns.any((row) => row['name'] == 'contact_numbers_json'), isTrue);

      final rows = await rawDatabase.query(
        'directory_businesses',
        where: 'id = ?',
        whereArgs: <Object?>['legacy-business'],
      );
      expect(rows, hasLength(1));
      expect(rows.single['name'], 'نشاط محفوظ قبل الترقية');
      expect(rows.single['contact_numbers_json'], '[]');

      await upgraded.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
