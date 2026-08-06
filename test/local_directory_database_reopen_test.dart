import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('يعيد فتح SQLite تلقائيًا إذا أصبح المرجع المخزن مغلقًا', () async {
    final database = LocalDirectoryDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    final firstConnection = await database.database;
    expect(firstConnection.isOpen, isTrue);
    await firstConnection.close();
    expect(firstConnection.isOpen, isFalse);

    final snapshot = await database.initializeWithSeedData();
    final reopenedConnection = await database.database;

    expect(reopenedConnection.isOpen, isTrue);
    expect(identical(reopenedConnection, firstConnection), isFalse);
    expect(snapshot.isInitialized, isTrue);
    expect(snapshot.categories, isNotEmpty);
  });

  test('تشارك الطلبات المتزامنة عملية فتح واحدة صالحة', () async {
    final database = LocalDirectoryDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    final connections = await Future.wait(
      List<Future<Database>>.generate(
        8,
        (_) => database.database,
      ),
    );

    expect(connections.every((connection) => connection.isOpen), isTrue);
    expect(
      connections
          .every((connection) => identical(connection, connections.first)),
      isTrue,
    );
  });
}
