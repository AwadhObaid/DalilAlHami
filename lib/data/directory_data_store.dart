import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/constants/app_catalog.dart';
import '../core/services/supabase_service.dart';
import '../models/business.dart';
import '../models/service_category.dart';
import 'local/database/local_directory_database.dart';
import 'local_directory_store.dart';
import 'repositories/directory_sync_repository.dart';
import 'repositories/supabase_directory_repository.dart';
import 'sync/directory_sync_delta.dart';

enum DirectoryDataSource {
  supabase,
  sqliteCache,
  bundledSeed,
  memoryFallback,
}

class DirectoryDataStore extends ChangeNotifier {
  DirectoryDataStore._();

  static final DirectoryDataStore instance = DirectoryDataStore._();

  final LocalDirectoryDatabase _database = LocalDirectoryDatabase.instance;
  final LocalDirectoryStore _memoryStore = LocalDirectoryStore.instance;

  List<ServiceCategory> _categories = const [];
  List<Business> _businesses = const [];
  List<String> _advertisements = const [];

  DirectoryDataSource? _source;
  Object? _lastError;
  DateTime? _lastSyncedAt;
  int _lastSyncVersion = 0;
  int _lastSyncChangeCount = 0;
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _hasLoaded = false;
  Future<void>? _activeSync;

  bool get isLoading => _isLoading || _isSyncing;

  bool get isInitialLoading => _isLoading && !_hasLoaded;

  bool get isRefreshing => _isSyncing && _hasLoaded;

  bool get hasLoaded => _hasLoaded;

  bool get hasData => _categories.isNotEmpty || _businesses.isNotEmpty;

  DirectoryDataSource? get source => _source;

  bool get usesSupabase => _source == DirectoryDataSource.supabase;

  bool get usesSqliteCache =>
      _source == DirectoryDataSource.supabase ||
      _source == DirectoryDataSource.sqliteCache ||
      _source == DirectoryDataSource.bundledSeed;

  bool get usesLocalFallback => !usesSupabase;

  DateTime? get lastSyncedAt => _lastSyncedAt;

  int get lastSyncVersion => _lastSyncVersion;

  int get lastSyncChangeCount => _lastSyncChangeCount;

  String? get lastSyncLabel {
    final value = _lastSyncedAt?.toLocal();
    if (value == null) {
      return null;
    }

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(value.day)}/${twoDigits(value.month)}/'
        '${value.year} ${twoDigits(value.hour)}:'
        '${twoDigits(value.minute)}';
  }

  String? get fallbackMessage {
    return switch (_source) {
      DirectoryDataSource.supabase => null,
      DirectoryDataSource.sqliteCache =>
        'لا يتوفر اتصال حاليًا؛ تُعرض آخر نسخة محفوظة في الجهاز'
            '${lastSyncLabel == null ? '.' : ' بتاريخ $lastSyncLabel.'}',
      DirectoryDataSource.bundledSeed => SupabaseService.isConfigured
          ? 'تُعرض البيانات الأولية المحلية حتى تكتمل أول مزامنة.'
          : 'إعداد Supabase غير متاح؛ تعمل البيانات الأولية دون إنترنت.',
      DirectoryDataSource.memoryFallback =>
        'تعذر فتح قاعدة SQLite؛ تُعرض بيانات مرفقة مؤقتًا.',
      null => null,
    };
  }

  String get storageStatusTitle {
    return switch (_source) {
      DirectoryDataSource.supabase => 'متصل والمزامنة التزايدية مكتملة',
      DirectoryDataSource.sqliteCache => 'يعمل من قاعدة SQLite المحلية',
      DirectoryDataSource.bundledSeed => 'بيانات أولية محلية',
      DirectoryDataSource.memoryFallback => 'وضع محلي مؤقت',
      null => 'لم يُحمّل مصدر البيانات بعد',
    };
  }

  String get storageStatusSubtitle {
    if (_isSyncing) {
      return 'جارٍ طلب التغييرات الجديدة فقط من Supabase.';
    }

    return switch (_source) {
      DirectoryDataSource.supabase =>
        'إصدار المزامنة: $_lastSyncVersion، وآخر مزامنة'
            '${lastSyncLabel == null ? ' مكتملة.' : ': $lastSyncLabel.'}'
            ' التغييرات الأخيرة: $_lastSyncChangeCount.',
      DirectoryDataSource.sqliteCache =>
        fallbackMessage ?? 'تعمل آخر نسخة محفوظة دون إنترنت.',
      DirectoryDataSource.bundledSeed =>
        fallbackMessage ?? 'تعمل البيانات المرفقة مع التطبيق.',
      DirectoryDataSource.memoryFallback =>
        fallbackMessage ?? 'تعمل بيانات مؤقتة في الذاكرة.',
      null => 'لم يتم تحميل البيانات بعد.',
    };
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

  UnmodifiableListView<Business> get businesses =>
      UnmodifiableListView(_businesses);

  UnmodifiableListView<String> get advertisements =>
      UnmodifiableListView(_advertisements);

  @visibleForTesting
  void prepareBundledDataForTesting() {
    _categories = List<ServiceCategory>.unmodifiable(
      AppCatalog.allCategories,
    );
    _businesses = List<Business>.unmodifiable(
      _memoryStore.businesses,
    );
    _advertisements = List<String>.unmodifiable(
      AppCatalog.advertisements,
    );
    _source = DirectoryDataSource.bundledSeed;
    _lastError = null;
    _lastSyncedAt = null;
    _lastSyncVersion = 0;
    _lastSyncChangeCount = 0;
    _isLoading = false;
    _isSyncing = false;
    _hasLoaded = true;
    _activeSync = null;
  }

  Future<void> load({
    bool force = false,
  }) async {
    if (force) {
      await refresh();
      return;
    }

    if (_isLoading || _hasLoaded) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _loadLocalFirst();
    } catch (error, stackTrace) {
      debugPrint(
        'SQLite directory load failed: $error\n$stackTrace',
      );
      _loadMemoryFallback(error);
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }

    if (SupabaseService.isInitialized) {
      unawaited(_synchronizeFromSupabase());
    }
  }

  Future<void> refresh() {
    final existing = _activeSync;
    if (existing != null) {
      return existing;
    }

    final operation = _synchronizeFromSupabase();
    _activeSync = operation;

    return operation.whenComplete(() {
      if (identical(_activeSync, operation)) {
        _activeSync = null;
      }
    });
  }

  List<Business> search(String query) {
    return _businesses
        .where((business) => business.matchesSearch(query))
        .toList(growable: false);
  }

  List<Business> byCategory(
    ServiceCategory category,
  ) {
    return _businesses
        .where(
          (business) => business.belongsToCategory(
            id: category.id,
            name: category.name,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _loadLocalFirst() async {
    final snapshot = await _database.initializeWithSeedData();
    _applySnapshot(
      snapshot,
      source: snapshot.isSeedData
          ? DirectoryDataSource.bundledSeed
          : DirectoryDataSource.sqliteCache,
    );
    _lastSyncChangeCount = 0;
    _lastError = null;
  }

  Future<void> _synchronizeFromSupabase() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      if (!SupabaseService.isInitialized) {
        throw StateError(
          'Supabase is not initialized.',
        );
      }

      final DirectorySyncRepository repository = SupabaseDirectoryRepository(
        SupabaseService.client,
      );

      final delta = await _fetchChangesWithRetry(
        repository,
        afterVersion: _lastSyncVersion,
      );

      if (delta.isFullSnapshot && delta.categories.isEmpty) {
        throw StateError(
          'لم تُرجع المزامنة الكاملة أي تصنيفات نشطة.',
        );
      }

      final snapshot = await _database.applyRemoteChanges(
        delta: delta,
        syncedAt: DateTime.now().toUtc(),
      );

      _applySnapshot(
        snapshot,
        source: DirectoryDataSource.supabase,
      );
      _lastSyncChangeCount = delta.changeCount;
      _lastError = null;
    } catch (error, stackTrace) {
      debugPrint(
        'Supabase incremental synchronization failed: '
        '$error\n$stackTrace',
      );

      _lastError = error;

      if (_source == DirectoryDataSource.supabase) {
        _source = DirectoryDataSource.sqliteCache;
      }

      if (!hasData) {
        try {
          await _loadLocalFirst();
        } catch (_) {
          _loadMemoryFallback(error);
        }
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<DirectorySyncDelta> _fetchChangesWithRetry(
    DirectorySyncRepository repository, {
    required int afterVersion,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        return await repository.fetchChanges(
          afterVersion: afterVersion,
        );
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;

        if (attempt < 2) {
          await Future<void>.delayed(
            const Duration(milliseconds: 600),
          );
        }
      }
    }

    Error.throwWithStackTrace(
      lastError ?? StateError('Incremental synchronization failed.'),
      lastStackTrace ?? StackTrace.current,
    );
  }

  void _applySnapshot(
    DirectoryCacheSnapshot snapshot, {
    required DirectoryDataSource source,
  }) {
    _categories = List<ServiceCategory>.unmodifiable(
      snapshot.categories,
    );
    _businesses = List<Business>.unmodifiable(
      snapshot.businesses,
    );
    _advertisements = List<String>.unmodifiable(
      snapshot.advertisements.isEmpty
          ? AppCatalog.advertisements
          : snapshot.advertisements,
    );
    _lastSyncedAt = snapshot.lastSyncedAt;
    _lastSyncVersion = snapshot.lastSyncVersion;
    _source = source;
  }

  void _loadMemoryFallback(Object error) {
    _categories = List<ServiceCategory>.unmodifiable(
      AppCatalog.allCategories,
    );
    _businesses = List<Business>.unmodifiable(
      _memoryStore.businesses,
    );
    _advertisements = List<String>.unmodifiable(
      AppCatalog.advertisements,
    );
    _source = DirectoryDataSource.memoryFallback;
    _lastError = error;
    _lastSyncVersion = 0;
    _lastSyncChangeCount = 0;
  }
}
