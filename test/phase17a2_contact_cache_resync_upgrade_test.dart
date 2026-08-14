import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/data/sync/directory_sync_delta.dart';
import 'package:hami_guide/models/business.dart';
import 'package:hami_guide/models/business_contact_number.dart';
import 'package:hami_guide/models/service_category.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'schema 11 cache resets directory sync marker on v12 upgrade and backfills contacts',
    () async {
      final directory =
          await Directory.systemTemp.createTemp('dalil_contact_resync_v12_');
      final path = '${directory.path}${Platform.pathSeparator}directory.db';

      try {
        final oldDatabase = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 11,
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
                  contact_numbers_json TEXT NOT NULL DEFAULT '[]',
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
                CREATE TABLE directory_metadata (
                  key TEXT PRIMARY KEY,
                  value TEXT NOT NULL
                )
                ''',
              );

              await database.insert(
                'directory_businesses',
                <String, Object?>{
                  'id': 'legacy-contact-business',
                  'name': 'نشاط سبق أن تزامن بالإصدار القديم',
                  'phone': '777000111',
                  'whatsapp': '733000222',
                  'category_name': 'خدمات',
                  'place': 'الحامي',
                  'category_id': 'contact-category',
                  'category_slug': 'services',
                  'contact_numbers_json': '[]',
                  'is_remote': 1,
                  'sync_version': 514,
                },
              );

              await database.insert(
                'directory_metadata',
                const <String, Object?>{
                  'key': 'cache_initialized',
                  'value': '1',
                },
              );
              await database.insert(
                'directory_metadata',
                const <String, Object?>{
                  'key': 'cache_kind',
                  'value': 'remote',
                },
              );
              await database.insert(
                'directory_metadata',
                const <String, Object?>{
                  'key': 'last_sync_version',
                  'value': '529',
                },
              );
              await database.insert(
                'directory_metadata',
                const <String, Object?>{
                  'key': 'last_synced_at',
                  'value': '2026-08-14T18:00:00Z',
                },
              );
            },
          ),
        );
        await oldDatabase.close();

        final upgraded = LocalDirectoryDatabase(
          databaseFactory: databaseFactoryFfi,
          databasePath: path,
        );

        try {
          final afterUpgrade = await upgraded.readSnapshot();

          expect(
            afterUpgrade.lastSyncVersion,
            0,
            reason: 'Schema 12 must force one full directory snapshot after '
                'older clients may have advanced the sync marker while '
                'ignoring nested contact numbers.',
          );
          expect(afterUpgrade.lastSyncedAt, isNull);
          expect(afterUpgrade.businesses, hasLength(1));
          expect(afterUpgrade.businesses.single.contactNumbers, isEmpty);
          expect(
            afterUpgrade.businesses.single.name,
            'نشاط سبق أن تزامن بالإصدار القديم',
          );

          const category = ServiceCategory(
            id: 'contact-category',
            name: 'خدمات',
            slug: 'services',
            iconName: 'storefront',
            sortOrder: 0,
            displayGroup: CategoryDisplayGroup.services,
            syncVersion: 530,
          );

          const refreshedBusiness = Business(
            id: 'legacy-contact-business',
            name: 'نشاط سبق أن تزامن بالإصدار القديم',
            phone: '777000111',
            whatsapp: '733000222',
            category: 'خدمات',
            place: 'الحامي',
            categoryId: 'contact-category',
            categorySlug: 'services',
            contactNumbers: <BusinessContactNumber>[
              BusinessContactNumber(
                id: 'contact-primary',
                businessId: 'legacy-contact-business',
                phoneNumber: '777000111',
                label: 'الرئيسي',
                isPrimary: true,
                sortOrder: 0,
                syncVersion: 531,
              ),
              BusinessContactNumber(
                id: 'contact-whatsapp',
                businessId: 'legacy-contact-business',
                phoneNumber: '733000222',
                label: 'واتساب',
                supportsWhatsApp: true,
                sortOrder: 1,
                syncVersion: 532,
              ),
            ],
            isRemote: true,
            syncVersion: 532,
          );

          final refreshed = await upgraded.applyRemoteChanges(
            delta: const DirectorySyncDelta(
              serverVersion: 532,
              isFullSnapshot: true,
              categories: <ServiceCategory>[category],
              businesses: <Business>[refreshedBusiness],
            ),
            syncedAt: DateTime.utc(2026, 8, 14, 19),
          );

          expect(refreshed.lastSyncVersion, 532);
          expect(refreshed.businesses, hasLength(1));
          expect(refreshed.businesses.single.contactNumbers, hasLength(2));
          expect(
            refreshed.businesses.single.contactNumbers.last.supportsWhatsApp,
            isTrue,
          );

          final reread = await upgraded.readSnapshot();
          expect(reread.lastSyncVersion, 532);
          expect(reread.businesses.single.contactNumbers, hasLength(2));
          expect(
            reread.businesses.single.contactNumbers.first.phoneNumber,
            '777000111',
          );
          expect(
            reread.businesses.single.contactNumbers.last.phoneNumber,
            '733000222',
          );
        } finally {
          await upgraded.close();
        }
      } finally {
        if (await databaseFactoryFfi.databaseExists(path)) {
          await databaseFactoryFfi.deleteDatabase(path);
        }
        await directory.delete(recursive: true);
      }
    },
  );
}
