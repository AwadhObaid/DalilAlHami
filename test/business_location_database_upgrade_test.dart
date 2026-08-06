import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/data/sync/directory_sync_delta.dart';
import 'package:hami_guide/models/business.dart';
import 'package:hami_guide/models/service_category.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('يرقي كاش الإصدار 9 ويحفظ موقع النشاط', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dalil_location_upgrade_',
    );
    final path = '${directory.path}${Platform.pathSeparator}directory.db';

    try {
      final oldDatabase = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 9,
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
          },
        ),
      );
      await oldDatabase.close();

      final upgraded = LocalDirectoryDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: path,
      );

      const category = ServiceCategory(
        id: 'location-category',
        name: 'خدمات',
        slug: 'services',
        iconName: 'storefront',
        sortOrder: 0,
        displayGroup: CategoryDisplayGroup.services,
        syncVersion: 10,
      );
      const business = Business(
        id: 'location-business',
        name: 'نشاط بموقع',
        phone: '777000111',
        category: 'خدمات',
        place: 'الحامي',
        categoryId: 'location-category',
        categorySlug: 'services',
        latitude: 14.80933,
        longitude: 49.82983,
        isRemote: true,
        syncVersion: 10,
      );

      final snapshot = await upgraded.applyRemoteChanges(
        delta: const DirectorySyncDelta(
          serverVersion: 10,
          isFullSnapshot: true,
          categories: [category],
          businesses: [business],
        ),
        syncedAt: DateTime.utc(2026, 8, 7, 1),
      );

      final saved = snapshot.businesses.single;
      expect(saved.latitude, 14.80933);
      expect(saved.longitude, 49.82983);
      expect(saved.hasLocation, isTrue);
      await upgraded.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
