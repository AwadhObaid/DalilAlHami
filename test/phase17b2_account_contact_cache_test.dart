import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/models/account_business.dart';
import 'package:hami_guide/models/business_contact_number.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('schema 13 persists normalized owned-business contacts offline',
      () async {
    final directory = await Directory.systemTemp.createTemp('dalil_b2_cache_');
    final path = '${directory.path}${Platform.pathSeparator}directory.db';
    final database = LocalDirectoryDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: path,
    );

    try {
      const business = AccountBusiness(
        id: 'b2-business',
        ownerId: 'b2-user',
        categoryId: 'category',
        categoryName: 'خدمات',
        name: 'نشاط متعدد الأرقام',
        description: '',
        phone: '05340080',
        whatsapp: '773272911',
        address: 'الحامي',
        status: 'local_pending',
        isActive: true,
        contactNumbers: <BusinessContactNumber>[
          BusinessContactNumber(
            id: 'local-1',
            businessId: 'b2-business',
            phoneNumber: '05340080',
            label: 'الرئيسي',
            isPrimary: true,
          ),
          BusinessContactNumber(
            id: 'local-2',
            businessId: 'b2-business',
            phoneNumber: '773272911',
            label: 'جوال',
            supportsWhatsApp: true,
            sortOrder: 1,
          ),
        ],
      );

      await database.upsertOwnedBusinessCache(business);
      final reread = await database.readOwnedBusinessCacheById(
        userId: 'b2-user',
        businessId: 'b2-business',
      );

      expect(reread, isNotNull);
      expect(reread!.contactNumbers, hasLength(2));
      expect(reread.contactNumbers.last.supportsWhatsApp, isTrue);
      expect(reread.phone, '05340080');
    } finally {
      await database.close();
      if (await databaseFactoryFfi.databaseExists(path)) {
        await databaseFactoryFfi.deleteDatabase(path);
      }
      await directory.delete(recursive: true);
    }
  });
}
