import 'package:sqflite_common/sqlite_api.dart';

import 'directory_database_platform_stub.dart'
    if (dart.library.io) 'directory_database_platform_io.dart'
    if (dart.library.html) 'directory_database_platform_web.dart' as platform;

Future<DatabaseFactory> resolveDirectoryDatabaseFactory() {
  return platform.resolveDirectoryDatabaseFactory();
}

Future<String> resolveDirectoryDatabasePath(
  DatabaseFactory factory,
) {
  return platform.resolveDirectoryDatabasePath(factory);
}
