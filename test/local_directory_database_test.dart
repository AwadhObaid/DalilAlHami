import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/data/sync/directory_sync_delta.dart';
import 'package:hami_guide/models/business.dart';
import 'package:hami_guide/models/directory_advertisement.dart';
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

  tearDown(() async {
    await database.close();
  });

  test('ينشئ قاعدة SQLite ويزرع البيانات الأولية والإعلانات', () async {
    final snapshot = await database.initializeWithSeedData();

    expect(snapshot.isInitialized, isTrue);
    expect(snapshot.isSeedData, isTrue);
    expect(snapshot.categories, isNotEmpty);
    expect(snapshot.businesses, isNotEmpty);
    expect(snapshot.advertisements, isNotEmpty);
    expect(snapshot.lastSyncedAt, isNull);
    expect(snapshot.lastSyncVersion, 0);
  });

  test('يطبق أول لقطة كاملة ويحفظ رقم إصدار الخادم', () async {
    await database.initializeWithSeedData();

    const category = ServiceCategory(
      id: 'remote-category',
      name: 'خدمة متزامنة',
      slug: 'synced-service',
      iconName: 'storefront',
      sortOrder: 1,
      displayGroup: CategoryDisplayGroup.services,
      syncVersion: 10,
    );
    const business = Business(
      id: 'remote-business',
      name: 'نشاط محفوظ دون إنترنت',
      phone: '777000111',
      category: 'خدمة متزامنة',
      place: 'الحامي',
      categoryId: 'remote-category',
      categorySlug: 'synced-service',
      isRemote: true,
      syncVersion: 11,
    );
    const advertisement = DirectoryAdvertisement(
      id: 'remote-advertisement',
      title: 'إعلان من Supabase',
      imagePath: 'admin/ad/expanded.jpg',
      compactImagePath: 'admin/ad/compact.jpg',
      sortOrder: 1,
      syncVersion: 12,
    );

    final snapshot = await database.applyRemoteChanges(
      delta: const DirectorySyncDelta(
        serverVersion: 12,
        isFullSnapshot: true,
        categories: [category],
        businesses: [business],
        advertisements: [advertisement],
      ),
      syncedAt: DateTime.utc(2026, 8, 3, 20, 30),
    );

    expect(snapshot.isSeedData, isFalse);
    expect(snapshot.lastSyncVersion, 12);
    expect(snapshot.categories.single.id, 'remote-category');
    expect(snapshot.businesses.single.id, 'remote-business');
    expect(snapshot.advertisements, ['إعلان من Supabase']);
    expect(
      snapshot.advertisementItems.single.imagePath,
      'admin/ad/expanded.jpg',
    );
    expect(
      snapshot.advertisementItems.single.compactImagePath,
      'admin/ad/compact.jpg',
    );
  });

  test('يحدّث سجلًا ويحذف سجلًا آخر دون استبدال القاعدة كاملة', () async {
    await database.initializeWithSeedData();

    const categoryOne = ServiceCategory(
      id: 'category-1',
      name: 'مطاعم',
      slug: 'restaurants',
      iconName: 'restaurant',
      sortOrder: 1,
      displayGroup: CategoryDisplayGroup.services,
      syncVersion: 1,
    );
    const categoryTwo = ServiceCategory(
      id: 'category-2',
      name: 'صيدليات',
      slug: 'pharmacies',
      iconName: 'local_pharmacy',
      sortOrder: 2,
      displayGroup: CategoryDisplayGroup.services,
      syncVersion: 2,
    );
    const businessOne = Business(
      id: 'business-1',
      name: 'مطعم قديم',
      phone: '777000111',
      category: 'مطاعم',
      place: 'الحامي',
      categoryId: 'category-1',
      categorySlug: 'restaurants',
      isRemote: true,
      syncVersion: 3,
    );
    const businessTwo = Business(
      id: 'business-2',
      name: 'صيدلية باقية',
      phone: '777000222',
      category: 'صيدليات',
      place: 'الحامي',
      categoryId: 'category-2',
      categorySlug: 'pharmacies',
      isRemote: true,
      syncVersion: 4,
    );

    await database.applyRemoteChanges(
      delta: const DirectorySyncDelta(
        serverVersion: 4,
        isFullSnapshot: true,
        categories: [categoryOne, categoryTwo],
        businesses: [businessOne, businessTwo],
      ),
      syncedAt: DateTime.utc(2026, 8, 3, 20),
    );

    const updatedBusiness = Business(
      id: 'business-2',
      name: 'صيدلية محدثة',
      phone: '777000222',
      category: 'صيدليات',
      place: 'السوق',
      categoryId: 'category-2',
      categorySlug: 'pharmacies',
      isRemote: true,
      syncVersion: 6,
    );

    final snapshot = await database.applyRemoteChanges(
      delta: const DirectorySyncDelta(
        serverVersion: 6,
        isFullSnapshot: false,
        deletedCategoryIds: {'category-1'},
        businesses: [updatedBusiness],
      ),
      syncedAt: DateTime.utc(2026, 8, 3, 21),
    );

    expect(snapshot.lastSyncVersion, 6);
    expect(snapshot.categories, hasLength(1));
    expect(snapshot.categories.single.id, 'category-2');
    expect(snapshot.businesses, hasLength(1));
    expect(snapshot.businesses.single.name, 'صيدلية محدثة');
    expect(snapshot.businesses.single.place, 'السوق');
  });

  test('يرفض الرجوع إلى رقم إصدار أقدم ويحافظ على البيانات', () async {
    await database.initializeWithSeedData();

    const category = ServiceCategory(
      id: 'category-1',
      name: 'مطاعم',
      slug: 'restaurants',
      iconName: 'restaurant',
      sortOrder: 1,
      displayGroup: CategoryDisplayGroup.services,
      syncVersion: 8,
    );

    await database.applyRemoteChanges(
      delta: const DirectorySyncDelta(
        serverVersion: 8,
        isFullSnapshot: true,
        categories: [category],
      ),
      syncedAt: DateTime.utc(2026, 8, 3, 22),
    );

    await expectLater(
      database.applyRemoteChanges(
        delta: const DirectorySyncDelta(
          serverVersion: 7,
          isFullSnapshot: false,
          deletedCategoryIds: {'category-1'},
        ),
        syncedAt: DateTime.utc(2026, 8, 3, 22, 30),
      ),
      throwsStateError,
    );

    final snapshot = await database.readSnapshot();
    expect(snapshot.lastSyncVersion, 8);
    expect(snapshot.categories.single.id, 'category-1');
  });

  test('يحفظ نتيجة Supabase بالطريقة المتوافقة مع 05A', () async {
    await database.initializeWithSeedData();

    const category = ServiceCategory(
      id: 'remote-category',
      name: 'خدمة متزامنة',
      slug: 'synced-service',
      iconName: 'storefront',
      sortOrder: 1,
      displayGroup: CategoryDisplayGroup.services,
    );
    const business = Business(
      id: 'remote-business',
      name: 'نشاط محفوظ دون إنترنت',
      phone: '777000111',
      whatsapp: '777000111',
      category: 'خدمة متزامنة',
      place: 'الحامي',
      details: 'بيانات قادمة من Supabase ومحفوظة محليًا.',
      categoryId: 'remote-category',
      categorySlug: 'synced-service',
      isFeatured: true,
      isRemote: true,
    );
    final syncedAt = DateTime.utc(2026, 8, 3, 17, 30);

    final snapshot = await database.replaceRemoteDirectoryData(
      categories: const [category],
      businesses: const [business],
      syncedAt: syncedAt,
    );

    expect(snapshot.isInitialized, isTrue);
    expect(snapshot.isSeedData, isFalse);
    expect(snapshot.lastSyncedAt, syncedAt);
    expect(snapshot.categories, hasLength(1));
    expect(snapshot.businesses, hasLength(1));
    expect(snapshot.advertisements, isNotEmpty);
  });
}
