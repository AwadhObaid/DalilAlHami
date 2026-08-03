import 'package:sqflite_common/sqlite_api.dart';

Future<DatabaseFactory> resolveDirectoryDatabaseFactory() {
  throw UnsupportedError(
    'SQLite cache is not enabled for the web build.',
  );
}

Future<String> resolveDirectoryDatabasePath(
  DatabaseFactory factory,
) {
  throw UnsupportedError(
    'SQLite cache is not enabled for the web build.',
  );
}
