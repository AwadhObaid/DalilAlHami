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
import 'sync_queue/supabase_sync_queue_gateway.dart';
import 'sync_queue/sync_conflict.dart';
import 'sync_queue/sync_queue_item.dart';
import 'sync_queue/sync_queue_processor.dart';

class DirectoryBackgroundSyncReport {
  const DirectoryBackgroundSyncReport({
    required this.beforeActionable,
    required this.afterActionable,
    required this.completedOperations,
    required this.failedOperations,
    required this.exhaustedOperations,
    required this.pendingConflicts,
    this.lastError,
  });

  final int beforeActionable;
  final int afterActionable;
  final int completedOperations;
  final int failedOperations;
  final int exhaustedOperations;
  final int pendingConflicts;
  final Object? lastError;

  bool get needsAttention => exhaustedOperations > 0 || pendingConflicts > 0;

  bool get hasTransientFailure => lastError != null && !needsAttention;
}

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
  SyncQueueSummary _syncQueueSummary = const SyncQueueSummary();
  SyncQueueProcessReport? _lastQueueReport;
  bool _isQueueProcessing = false;
  int _pendingSyncConflictCount = 0;

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

  SyncQueueSummary get syncQueueSummary => _syncQueueSummary;

  SyncQueueProcessReport? get lastQueueReport => _lastQueueReport;

  bool get isQueueProcessing => _isQueueProcessing;

  int get pendingSyncOperationCount => _syncQueueSummary.actionable;

  int get failedSyncOperationCount => _syncQueueSummary.failed;

  int get pendingSyncConflictCount => _pendingSyncConflictCount;

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
    final queueSuffix = _queueStatusSuffix;

    if (_isSyncing) {
      return 'جارٍ إرسال العمليات المحلية وطلب التغييرات الجديدة فقط '
          'من Supabase.$queueSuffix';
    }

    return switch (_source) {
      DirectoryDataSource.supabase =>
        'إصدار المزامنة: $_lastSyncVersion، وآخر مزامنة'
            '${lastSyncLabel == null ? ' مكتملة.' : ': $lastSyncLabel.'}'
            ' التغييرات الأخيرة: $_lastSyncChangeCount.$queueSuffix',
      DirectoryDataSource.sqliteCache =>
        '${fallbackMessage ?? 'تعمل آخر نسخة محفوظة دون إنترنت.'}'
            '$queueSuffix',
      DirectoryDataSource.bundledSeed =>
        '${fallbackMessage ?? 'تعمل البيانات المرفقة مع التطبيق.'}'
            '$queueSuffix',
      DirectoryDataSource.memoryFallback =>
        '${fallbackMessage ?? 'تعمل بيانات مؤقتة في الذاكرة.'}'
            '$queueSuffix',
      null => 'لم يتم تحميل البيانات بعد.$queueSuffix',
    };
  }

  String get _queueStatusSuffix {
    if (_isQueueProcessing) {
      return ' جارٍ معالجة طابور العمليات.';
    }
    if (_pendingSyncConflictCount > 0) {
      return ' توجد $_pendingSyncConflictCount تعارضات مزامنة '
          'تحتاج إلى قرار.';
    }
    if (_syncQueueSummary.exhausted > 0) {
      return ' توجد ${_syncQueueSummary.exhausted} عملية متوقفة '
          'بعد استنفاد المحاولات.';
    }
    if (_syncQueueSummary.actionable > 0) {
      return ' توجد ${_syncQueueSummary.actionable} عملية محلية '
          'بانتظار المزامنة.';
    }
    return '';
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
    _syncQueueSummary = const SyncQueueSummary();
    _lastQueueReport = null;
    _isQueueProcessing = false;
    _pendingSyncConflictCount = 0;
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
      unawaited(_flushQueueThenSynchronize());
    }
  }

  Future<void> refresh() {
    final existing = _activeSync;
    if (existing != null) {
      return existing;
    }

    final operation = _flushQueueThenSynchronize();
    _activeSync = operation;

    return operation.whenComplete(() {
      if (identical(_activeSync, operation)) {
        _activeSync = null;
      }
    });
  }

  Future<SyncQueueItem> enqueueBusinessOperation({
    required SyncQueueOperationType operationType,
    required Map<String, dynamic> payload,
    String? entityId,
    String? operationId,
    String? deduplicationKey,
    int maxAttempts = 5,
    int priority = 0,
    bool processWhenOnline = true,
  }) async {
    final userId = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (userId == null || userId.isEmpty) {
      throw StateError(
        'يجب تسجيل الدخول قبل حفظ عملية مزامنة محلية.',
      );
    }

    final resolvedOperationId = operationId ?? SyncQueueOperationId.create();
    final item = await _database.enqueueSyncOperation(
      SyncQueueEnqueueRequest(
        userId: userId,
        operationId: resolvedOperationId,
        deduplicationKey: deduplicationKey ?? resolvedOperationId,
        entityType: SyncQueueEntityType.business,
        operationType: operationType,
        entityId: entityId,
        payload: payload,
        maxAttempts: maxAttempts,
        priority: priority,
      ),
    );

    await _refreshQueueSummary();
    notifyListeners();

    if (processWhenOnline && SupabaseService.isInitialized) {
      unawaited(refresh());
    }

    return item;
  }

  Future<void> retryFailedSyncOperations({
    String? operationId,
  }) async {
    final userId = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (userId == null || userId.isEmpty) {
      return;
    }

    await _database.retryFailedSyncOperations(
      userId: userId,
      operationId: operationId,
    );
    await _refreshQueueSummary();
    notifyListeners();

    if (SupabaseService.isInitialized) {
      await refresh();
    }
  }

  Future<List<SyncQueueItem>> readCurrentUserSyncOperations({
    int limit = 100,
  }) async {
    final userId = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (userId == null || userId.isEmpty) {
      return const <SyncQueueItem>[];
    }

    return _database.readSyncOperations(
      userId: userId,
      limit: limit,
    );
  }

  Future<List<SyncConflict>> readCurrentUserSyncConflicts({
    bool pendingOnly = false,
    int limit = 100,
  }) async {
    final userId = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (userId == null || userId.isEmpty) {
      return const <SyncConflict>[];
    }

    return _database.readSyncConflicts(
      userId: userId,
      pendingOnly: pendingOnly,
      limit: limit,
    );
  }

  Future<void> resolveSyncConflictUseServer(
    SyncConflict conflict,
  ) async {
    final userId = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (userId == null || userId != conflict.userId) {
      throw StateError('لا يمكن حل تعارض تابع لحساب آخر.');
    }

    await _database.applyServerConflictSnapshot(conflict);
    final resolvedAt = DateTime.now().toUtc();
    await _database.resolveSyncConflict(
      conflict: conflict,
      resolution: SyncConflictStatus.resolvedUseServer,
      resolvedAt: resolvedAt,
    );
    await _notifyRemoteConflictResolution(
      conflict: conflict,
      resolution: SyncConflictStatus.resolvedUseServer,
    );
    await _refreshQueueSummary();
    notifyListeners();
  }

  Future<void> resolveSyncConflictKeepLocal(
    SyncConflict conflict,
  ) async {
    final userId = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (userId == null || userId != conflict.userId) {
      throw StateError('لا يمكن حل تعارض تابع لحساب آخر.');
    }

    final payload = <String, dynamic>{
      ...conflict.localPayload,
      '_base_sync_version': conflict.serverSyncVersion,
    };
    final resolutionOperation = await enqueueBusinessOperation(
      operationType: conflict.operationType,
      entityId: conflict.entityId,
      payload: payload,
      priority: 30,
      processWhenOnline: false,
    );

    final resolvedAt = DateTime.now().toUtc();
    await _database.resolveSyncConflict(
      conflict: conflict,
      resolution: SyncConflictStatus.resolvedKeepLocal,
      resolvedAt: resolvedAt,
      resolutionOperationId: resolutionOperation.id,
    );
    await _notifyRemoteConflictResolution(
      conflict: conflict,
      resolution: SyncConflictStatus.resolvedKeepLocal,
      resolutionOperationId: resolutionOperation.id,
    );
    await _refreshQueueSummary();
    notifyListeners();

    if (SupabaseService.isInitialized) {
      await refresh();
    }
  }

  Future<void> _notifyRemoteConflictResolution({
    required SyncConflict conflict,
    required SyncConflictStatus resolution,
    String? resolutionOperationId,
  }) async {
    if (!SupabaseService.isInitialized) {
      return;
    }

    try {
      await SupabaseService.client.rpc(
        'resolve_directory_sync_conflict',
        params: <String, dynamic>{
          'p_conflict_id': conflict.id,
          'p_resolution': resolution.databaseValue,
          'p_resolution_operation_id': resolutionOperationId,
        },
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Remote conflict audit update failed: $error\n$stackTrace',
      );
    }
  }

  Future<void> refreshSyncQueueState() async {
    await _refreshQueueSummary();
    notifyListeners();
  }

  Future<void> processSyncQueueNow() async {
    await refresh();
  }

  Future<DirectoryBackgroundSyncReport> runBackgroundSync() async {
    if (!_hasLoaded) {
      try {
        await _loadLocalFirst();
        _hasLoaded = true;
      } catch (error, stackTrace) {
        debugPrint(
          'Background SQLite initialization failed: $error\n$stackTrace',
        );
        _loadMemoryFallback(error);
        _hasLoaded = true;
      }
    }

    await _refreshQueueSummary();
    final before = _syncQueueSummary;
    _lastQueueReport = null;
    _lastError = null;

    await _flushQueueThenSynchronize();
    await _refreshQueueSummary();

    final queueReport = _lastQueueReport;
    final calculatedCompleted = before.actionable > _syncQueueSummary.actionable
        ? before.actionable - _syncQueueSummary.actionable
        : 0;

    return DirectoryBackgroundSyncReport(
      beforeActionable: before.actionable,
      afterActionable: _syncQueueSummary.actionable,
      completedOperations: queueReport?.completed ?? calculatedCompleted,
      failedOperations: queueReport?.failed ?? 0,
      exhaustedOperations: _syncQueueSummary.exhausted,
      pendingConflicts: _pendingSyncConflictCount,
      lastError: _lastError ?? queueReport?.lastError,
    );
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
    await _refreshQueueSummary();
  }

  Future<void> _flushQueueThenSynchronize() async {
    try {
      await _processSyncQueue();
    } catch (error, stackTrace) {
      debugPrint(
        'Offline sync queue processing failed: $error\n$stackTrace',
      );
    }

    await _synchronizeFromSupabase();
  }

  Future<void> _processSyncQueue() async {
    if (!SupabaseService.isInitialized || _isQueueProcessing) {
      await _refreshQueueSummary();
      return;
    }

    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      await _refreshQueueSummary();
      return;
    }

    _isQueueProcessing = true;
    notifyListeners();

    try {
      final processor = SyncQueueProcessor(
        database: _database,
        gateway: SupabaseSyncQueueGateway(
          SupabaseService.client,
        ),
        userId: userId,
      );
      _lastQueueReport = await processor.processPending();
    } finally {
      await _refreshQueueSummary();
      _isQueueProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _refreshQueueSummary() async {
    final userId = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (userId == null || userId.isEmpty) {
      _syncQueueSummary = const SyncQueueSummary();
      _pendingSyncConflictCount = 0;
      return;
    }

    _syncQueueSummary = await _database.readSyncQueueSummary(
      userId: userId,
    );
    final conflicts = await _database.readSyncConflicts(
      userId: userId,
      pendingOnly: true,
      limit: 1000,
    );
    _pendingSyncConflictCount = conflicts.length;
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
      await _refreshQueueSummary();
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
    _syncQueueSummary = const SyncQueueSummary();
    _pendingSyncConflictCount = 0;
  }
}
