import '../sync/directory_sync_delta.dart';

abstract interface class DirectorySyncRepository {
  Future<DirectorySyncDelta> fetchChanges({
    required int afterVersion,
  });
}
