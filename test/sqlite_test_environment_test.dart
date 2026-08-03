import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('اختبار SQLite يستخدم قاعدة مستقلة داخل الذاكرة', () async {
    final database = LocalDirectoryDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );

    try {
      final snapshot = await database.initializeWithSeedData();

      expect(snapshot.isInitialized, isTrue);
      expect(snapshot.categories, isNotEmpty);
      expect(snapshot.businesses, isNotEmpty);
      expect(snapshot.advertisements, isNotEmpty);
    } finally {
      await database.close();
    }
  });
}
