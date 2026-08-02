import '../../core/constants/app_catalog.dart';
import '../../models/business.dart';
import '../../models/service_category.dart';
import '../local_directory_store.dart';
import 'directory_repository.dart';

class LocalDirectoryRepository implements DirectoryRepository {
  LocalDirectoryRepository({
    LocalDirectoryStore? localStore,
  }) : _localStore = localStore ?? LocalDirectoryStore.instance;

  final LocalDirectoryStore _localStore;

  @override
  Future<List<ServiceCategory>> fetchCategories() async {
    return List<ServiceCategory>.unmodifiable(
      AppCatalog.allCategories,
    );
  }

  @override
  Future<List<Business>> fetchApprovedBusinesses() async {
    return List<Business>.unmodifiable(
      _localStore.businesses,
    );
  }
}
