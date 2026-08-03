import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/models/business.dart';
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
  });

  test('يحفظ نتيجة Supabase ويقرأها من SQLite دون البيانات القديمة', () async {
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
    expect(snapshot.categories.single.id, 'remote-category');
    expect(snapshot.businesses, hasLength(1));
    expect(snapshot.businesses.single.id, 'remote-business');
    expect(snapshot.businesses.single.isFeatured, isTrue);
    expect(snapshot.businesses.single.isRemote, isTrue);
    expect(snapshot.advertisements, isNotEmpty);
  });
}
