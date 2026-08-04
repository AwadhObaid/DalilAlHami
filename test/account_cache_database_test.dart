import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/models/account_business.dart';
import 'package:hami_guide/models/account_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('يحفظ ملف الحساب والنشاط محليًا ويعيد قراءتهما', () async {
    final database = LocalDirectoryDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );

    const profile = AccountProfile(
      id: 'user-1',
      fullName: 'عوض',
      phone: '777000000',
      role: 'user',
      isActive: true,
      email: 'user@example.com',
    );
    const business = AccountBusiness(
      id: '11111111-1111-4111-8111-111111111111',
      ownerId: 'user-1',
      categoryId: 'category-1',
      categoryName: 'مطاعم',
      name: 'نشاط محلي',
      description: 'وصف',
      phone: '777000000',
      whatsapp: '777000000',
      address: 'الحامي',
      status: 'local_pending',
      isActive: true,
      localLogoPath: r'C:\temp\logo.jpg',
    );

    await database.upsertAccountProfile(profile);
    await database.upsertOwnedBusinessCache(business);

    final storedProfile = await database.readAccountProfile(userId: 'user-1');
    final storedBusiness =
        await database.readOwnedBusinessCache(userId: 'user-1');

    expect(storedProfile?.fullName, 'عوض');
    expect(storedBusiness?.name, 'نشاط محلي');
    expect(storedBusiness?.status, 'local_pending');
    expect(storedBusiness?.localLogoPath, r'C:\temp\logo.jpg');

    await database.deleteOwnedBusinessCache(
      userId: 'user-1',
      businessId: business.id,
    );
    expect(
      await database.readOwnedBusinessCache(userId: 'user-1'),
      isNull,
    );

    await database.close();
  });
}
