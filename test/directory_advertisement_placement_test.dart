import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/data/sync/directory_sync_delta.dart';
import 'package:hami_guide/models/directory_advertisement.dart';
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

  test('يحفظ موضع الإعلان ولا يعرض في الرئيسية إلا home_top', () async {
    await database.initializeWithSeedData();

    final snapshot = await database.applyRemoteChanges(
      delta: const DirectorySyncDelta(
        serverVersion: 20,
        isFullSnapshot: true,
        advertisements: [
          DirectoryAdvertisement(
            id: 'home-ad',
            title: 'إعلان الرئيسية',
            sortOrder: 1,
            placement: 'home_top',
            syncVersion: 19,
          ),
          DirectoryAdvertisement(
            id: 'category-ad',
            title: 'إعلان الأقسام',
            sortOrder: 2,
            placement: 'category',
            syncVersion: 20,
          ),
        ],
      ),
      syncedAt: DateTime.utc(2026, 8, 6, 12),
    );

    expect(snapshot.advertisements, ['إعلان الرئيسية']);
  });

  test('يقرأ business_id وplacement من حمولة المزامنة', () {
    final advertisement = DirectoryAdvertisement.fromSupabase({
      'id': 'ad-1',
      'business_id': 'business-1',
      'title': 'إعلان نشاط',
      'placement': 'business_list',
      'sort_order': 3,
      'is_active': true,
    });

    expect(advertisement.businessId, 'business-1');
    expect(advertisement.placement, 'business_list');
  });
}
