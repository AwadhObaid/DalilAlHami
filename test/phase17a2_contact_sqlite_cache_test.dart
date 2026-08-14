import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/data/sync/directory_sync_delta.dart';
import 'package:hami_guide/models/business.dart';
import 'package:hami_guide/models/business_contact_number.dart';
import 'package:hami_guide/models/service_category.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalDirectoryDatabase database;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    database = LocalDirectoryDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });

  tearDown(() async => database.close());

  test('multiple contact numbers survive SQLite offline cache round-trip',
      () async {
    await database.initializeWithSeedData();

    const category = ServiceCategory(
      id: 'contact-category',
      name: 'خدمات',
      slug: 'services',
      iconName: 'storefront',
      sortOrder: 1,
      displayGroup: CategoryDisplayGroup.services,
      syncVersion: 200,
    );

    const business = Business(
      id: 'contact-business',
      name: 'نشاط متعدد الأرقام',
      phone: '777111222',
      whatsapp: '733444555',
      category: 'خدمات',
      place: 'الحامي',
      categoryId: 'contact-category',
      categorySlug: 'services',
      contactNumbers: <BusinessContactNumber>[
        BusinessContactNumber(
          id: 'contact-1',
          businessId: 'contact-business',
          phoneNumber: '777111222',
          label: 'الرئيسي',
          isPrimary: true,
          sortOrder: 0,
          syncVersion: 201,
        ),
        BusinessContactNumber(
          id: 'contact-2',
          businessId: 'contact-business',
          phoneNumber: '733444555',
          label: 'واتساب',
          supportsWhatsApp: true,
          sortOrder: 1,
          syncVersion: 202,
        ),
      ],
      isRemote: true,
      syncVersion: 202,
    );

    final synced = await database.applyRemoteChanges(
      delta: const DirectorySyncDelta(
        serverVersion: 202,
        isFullSnapshot: true,
        categories: <ServiceCategory>[category],
        businesses: <Business>[business],
      ),
      syncedAt: DateTime.utc(2026, 8, 14, 16, 30),
    );

    expect(synced.businesses.single.contactNumbers, hasLength(2));

    final offline = await database.readSnapshot();
    expect(offline.businesses.single.contactNumbers, hasLength(2));
    expect(offline.businesses.single.contactNumbers.first.phoneNumber,
        '777111222');
    expect(
        offline.businesses.single.contactNumbers.last.phoneNumber, '733444555');
    expect(
        offline.businesses.single.contactNumbers.last.supportsWhatsApp, isTrue);
  });
}
