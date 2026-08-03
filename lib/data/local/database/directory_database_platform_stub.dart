import 'package:sqflite_common/sqlite_api.dart';

Future<DatabaseFactory> resolveDirectoryDatabaseFactory() {
  throw UnsupportedError(
    'SQLite is not supported on this platform.',
  );
}

Future<String> resolveDirectoryDatabasePath(
  DatabaseFactory factory,
) {
  throw UnsupportedError(
    'SQLite is not supported on this platform.',
  );
}
