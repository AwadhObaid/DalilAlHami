import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/models/account_business.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('يسمح كاش الحساب بحفظ أكثر من نشاط للمستخدم نفسه', () async {
    final database = LocalDirectoryDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );

    await database.upsertOwnedBusinessCache(
      _business(id: 'business-1', name: 'النشاط الأول'),
    );
    await database.upsertOwnedBusinessCache(
      _business(id: 'business-2', name: 'النشاط الثاني'),
    );

    final businesses = await database.readOwnedBusinessesCache(
      userId: 'user-1',
    );
    expect(businesses, hasLength(2));
    expect(businesses.map((item) => item.id).toSet(), {
      'business-1',
      'business-2',
    });

    await database.close();
  });

  test('يرقي كاش الإصدار 4 ويحذف قيد النشاط الواحد دون فقده', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dalil_multi_business_upgrade_',
    );
    final path = '${directory.path}${Platform.pathSeparator}directory.db';

    try {
      final oldDatabase = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (database, version) async {
            await database.execute(
              '''
              CREATE TABLE account_businesses_cache (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL UNIQUE,
                category_id TEXT NOT NULL DEFAULT '',
                category_name TEXT NOT NULL DEFAULT '',
                name TEXT NOT NULL DEFAULT '',
                description TEXT NOT NULL DEFAULT '',
                phone TEXT NOT NULL DEFAULT '',
                whatsapp TEXT NOT NULL DEFAULT '',
                address TEXT NOT NULL DEFAULT 'الحامي',
                logo_url TEXT,
                local_logo_path TEXT,
                status TEXT NOT NULL DEFAULT 'draft',
                rejection_reason TEXT,
                is_active INTEGER NOT NULL DEFAULT 1,
                updated_at TEXT NOT NULL
              )
              ''',
            );
          },
        ),
      );
      await oldDatabase.insert('account_businesses_cache', {
        'id': 'business-old',
        'user_id': 'user-1',
        'name': 'النشاط القديم',
        'updated_at': DateTime.utc(2026, 8, 4).toIso8601String(),
      });
      await oldDatabase.close();

      final upgraded = LocalDirectoryDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: path,
      );
      await upgraded.upsertOwnedBusinessCache(
        _business(id: 'business-new', name: 'النشاط الجديد'),
      );
      final businesses = await upgraded.readOwnedBusinessesCache(
        userId: 'user-1',
      );

      expect(businesses, hasLength(2));
      expect(
        businesses.map((item) => item.id).toSet(),
        {'business-old', 'business-new'},
      );
      await upgraded.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

AccountBusiness _business({required String id, required String name}) {
  return AccountBusiness(
    id: id,
    ownerId: 'user-1',
    categoryId: 'category-1',
    categoryName: 'مطاعم',
    name: name,
    description: '',
    phone: '777000000',
    whatsapp: '777000000',
    address: 'الحامي',
    status: 'local_pending',
    isActive: true,
  );
}
