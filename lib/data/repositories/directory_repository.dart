import '../../models/business.dart';
import '../../models/service_category.dart';

abstract interface class DirectoryRepository {
  Future<List<ServiceCategory>> fetchCategories();

  Future<List<Business>> fetchApprovedBusinesses();
}
