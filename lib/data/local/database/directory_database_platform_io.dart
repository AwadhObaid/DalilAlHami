import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

Future<DatabaseFactory> resolveDirectoryDatabaseFactory() async {
  return sqflite.databaseFactory;
}

Future<String> resolveDirectoryDatabasePath(
  DatabaseFactory factory,
) async {
  final databaseDirectory = await factory.getDatabasesPath();

  return path.join(
    databaseDirectory,
    'dalil_al_hami_offline.db',
  );
}
