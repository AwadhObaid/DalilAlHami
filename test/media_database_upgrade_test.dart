import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/data/sync/directory_sync_delta.dart';
import 'package:hami_guide/models/directory_advertisement.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('يرقي كاش الإصدار 7 ويحفظ صورة الإعلان المصغرة', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dalil_media_upgrade_',
    );
    final path = '${directory.path}${Platform.pathSeparator}directory.db';

    try {
      final oldDatabase = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (database, version) async {
            await database.execute(
              '''
              CREATE TABLE directory_advertisements (
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
          },
        ),
      );
      await oldDatabase.insert('directory_advertisements', {
        'id': 'old-ad',
        'title': 'إعلان قديم',
        'image_path': 'admin/old/expanded.jpg',
        'sort_order': 0,
      });
      await oldDatabase.close();

      final upgraded = LocalDirectoryDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: path,
      );
      final initial = await upgraded.readSnapshot();
      expect(initial.advertisementItems.single.id, 'old-ad');
      expect(initial.advertisementItems.single.compactImagePath, isNull);

      final snapshot = await upgraded.applyRemoteChanges(
        delta: const DirectorySyncDelta(
          serverVersion: 8,
          isFullSnapshot: true,
          advertisements: <DirectoryAdvertisement>[
            DirectoryAdvertisement(
              id: 'new-ad',
              title: 'إعلان بوسائط مزدوجة',
              imagePath: 'admin/new/expanded.jpg',
              compactImagePath: 'admin/new/compact.jpg',
              sortOrder: 0,
              syncVersion: 8,
            ),
          ],
        ),
        syncedAt: DateTime.utc(2026, 8, 6, 18),
      );

      expect(snapshot.advertisementItems.single.id, 'new-ad');
      expect(
        snapshot.advertisementItems.single.compactImagePath,
        'admin/new/compact.jpg',
      );
      await upgraded.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
