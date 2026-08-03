import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/services/supabase_service.dart';
import '../models/business.dart';
import '../models/service_category.dart';
import 'local_directory_store.dart';
import 'repositories/directory_repository.dart';
import 'repositories/local_directory_repository.dart';
import 'repositories/supabase_directory_repository.dart';

enum DirectoryDataSource {
  supabase,
  localFallback,
}

class DirectoryDataStore extends ChangeNotifier {
  DirectoryDataStore._();

  static final DirectoryDataStore instance = DirectoryDataStore._();

  final LocalDirectoryStore _localStore = LocalDirectoryStore.instance;

  List<ServiceCategory> _categories = const [];
  List<Business> _remoteBusinesses = const [];

  DirectoryDataSource? _source;
  Object? _lastError;
  bool _isLoading = false;
  bool _hasLoaded = false;

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  DirectoryDataSource? get source => _source;

  bool get usesSupabase => _source == DirectoryDataSource.supabase;

  bool get usesLocalFallback => _source == DirectoryDataSource.localFallback;

  String? get fallbackMessage {
    if (!usesLocalFallback) {
      return null;
    }

    if (!SupabaseService.isConfigured) {
      return 'إعداد Supabase غير متاح؛ تُعرض البيانات المحلية.';
    }

    return 'تعذر تحديث البيانات من الإنترنت؛ تُعرض نسخة محلية مؤقتة.';
  }

  Object? get lastError => _lastError;

  UnmodifiableListView<ServiceCategory> get categories =>
      UnmodifiableListView(_categories);

  List<ServiceCategory> get serviceCategories => _categories
      .where((category) => !category.isTransport)
      .toList(growable: false);

  List<ServiceCategory> get transportCategories => _categories
      .where((category) => category.isTransport)
      .toList(growable: false);

  UnmodifiableListView<Business> get businesses {
    final values =
        usesLocalFallback ? _localStore.businesses : _remoteBusinesses;

    return UnmodifiableListView(values);
  }

  Future<void> load({
    bool force = false,
  }) async {
    if (_isLoading || (_hasLoaded && !force)) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      if (!SupabaseService.isInitialized) {
        await _loadFallback(
          error: StateError('Supabase is not initialized.'),
        );
        return;
      }

      final DirectoryRepository repository = SupabaseDirectoryRepository(
        SupabaseService.client,
      );

      final loadedCategories = await repository.fetchCategories();

      if (loadedCategories.isEmpty) {
        throw StateError(
          'لم تُرجع قاعدة البيانات أي تصنيفات نشطة.',
        );
      }

      final loadedBusinesses = await repository.fetchApprovedBusinesses();

      _categories = loadedCategories;
      _remoteBusinesses = loadedBusinesses;
      _source = DirectoryDataSource.supabase;
      _lastError = null;
    } catch (error, stackTrace) {
      debugPrint(
        'Supabase directory load failed: $error\n$stackTrace',
      );

      await _loadFallback(error: error);
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(force: true);

  List<Business> search(String query) {
    return businesses
        .where((business) => business.matchesSearch(query))
        .toList(growable: false);
  }

  List<Business> byCategory(
    ServiceCategory category,
  ) {
    return businesses
        .where(
          (business) => business.belongsToCategory(
            id: category.id,
            name: category.name,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _loadFallback({
    required Object error,
  }) async {
    final repository = LocalDirectoryRepository(
      localStore: _localStore,
    );

    _categories = await repository.fetchCategories();
    _remoteBusinesses = const [];
    _source = DirectoryDataSource.localFallback;
    _lastError = error;
  }
}
