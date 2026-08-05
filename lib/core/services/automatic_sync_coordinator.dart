import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/directory_data_store.dart';
import '../config/supabase_config.dart';
import 'auth_session_store.dart';
import 'background_sync_service.dart';
import 'background_sync_settings.dart';
import 'network_reachability.dart';
import 'supabase_service.dart';

enum AutomaticSyncTrigger {
  startup,
  authentication,
  appResume,
  periodic,
  queueChanged,
  manual,
}

enum AutomaticSyncPhase {
  idle,
  checkingConnection,
  syncing,
  offline,
  waitingRetry,
  completed,
  attentionRequired,
}

class AutomaticSyncMetrics {
  const AutomaticSyncMetrics({
    this.pendingOperations = 0,
    this.failedOperations = 0,
    this.exhaustedOperations = 0,
    this.pendingConflicts = 0,
    this.lastError,
  });

  final int pendingOperations;
  final int failedOperations;
  final int exhaustedOperations;
  final int pendingConflicts;
  final Object? lastError;

  bool get hasAttention => exhaustedOperations > 0 || pendingConflicts > 0;
}

class AutomaticSyncSnapshot {
  const AutomaticSyncSnapshot({
    this.phase = AutomaticSyncPhase.idle,
    this.message = 'المزامنة التلقائية جاهزة.',
    this.trigger = AutomaticSyncTrigger.startup,
    this.pendingOperations = 0,
    this.failedOperations = 0,
    this.exhaustedOperations = 0,
    this.pendingConflicts = 0,
    this.consecutiveNetworkFailures = 0,
    this.eventId = 0,
    this.announce = false,
    this.lastStartedAt,
    this.lastCompletedAt,
    this.nextRetryAt,
  });

  final AutomaticSyncPhase phase;
  final String message;
  final AutomaticSyncTrigger trigger;
  final int pendingOperations;
  final int failedOperations;
  final int exhaustedOperations;
  final int pendingConflicts;
  final int consecutiveNetworkFailures;
  final int eventId;
  final bool announce;
  final DateTime? lastStartedAt;
  final DateTime? lastCompletedAt;
  final DateTime? nextRetryAt;

  bool get isBusy =>
      phase == AutomaticSyncPhase.checkingConnection ||
      phase == AutomaticSyncPhase.syncing;

  bool get isAttention =>
      phase == AutomaticSyncPhase.attentionRequired ||
      phase == AutomaticSyncPhase.offline ||
      phase == AutomaticSyncPhase.waitingRetry;

  bool get shouldShowBanner => switch (phase) {
        AutomaticSyncPhase.idle => false,
        AutomaticSyncPhase.completed => announce,
        _ => true,
      };

  String? get nextRetryLabel {
    final value = nextRetryAt?.toLocal();
    if (value == null) {
      return null;
    }

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}

abstract final class AutomaticSyncRetryPolicy {
  static const Duration normalInterval = Duration(minutes: 5);

  static Duration delayForFailure(int failureCount) {
    return switch (failureCount) {
      <= 1 => const Duration(seconds: 30),
      2 => const Duration(minutes: 2),
      3 => const Duration(minutes: 5),
      4 => const Duration(minutes: 15),
      _ => const Duration(minutes: 30),
    };
  }
}

typedef AutomaticSyncAction = Future<void> Function();
typedef AutomaticSyncProbe = Future<bool> Function();
typedef AutomaticSyncEligibility = bool Function();
typedef AutomaticSyncMetricsReader = AutomaticSyncMetrics Function();

class AutomaticSyncCoordinator extends ChangeNotifier
    with WidgetsBindingObserver {
  AutomaticSyncCoordinator({
    required AutomaticSyncAction syncAction,
    required AutomaticSyncProbe networkProbe,
    required AutomaticSyncEligibility canSync,
    required AutomaticSyncMetricsReader readMetrics,
    this.automaticSchedulingEnabled = true,
    this.normalInterval = AutomaticSyncRetryPolicy.normalInterval,
  })  : _syncAction = syncAction,
        _networkProbe = networkProbe,
        _canSync = canSync,
        _readMetrics = readMetrics;

  factory AutomaticSyncCoordinator.app() {
    final store = DirectoryDataStore.instance;
    final authStore = AuthSessionStore.instance;

    return AutomaticSyncCoordinator(
      syncAction: store.refresh,
      networkProbe: () {
        final uri = Uri.tryParse(SupabaseConfig.url.trim());
        return hasNetworkConnection(host: uri?.host ?? '');
      },
      canSync: () => SupabaseService.isInitialized && authStore.isAuthenticated,
      readMetrics: () => AutomaticSyncMetrics(
        pendingOperations: store.pendingSyncOperationCount,
        failedOperations: store.failedSyncOperationCount,
        exhaustedOperations: store.syncQueueSummary.exhausted,
        pendingConflicts: store.pendingSyncConflictCount,
        lastError: store.lastError,
      ),
    );
  }

  static final AutomaticSyncCoordinator instance =
      AutomaticSyncCoordinator.app();

  final AutomaticSyncAction _syncAction;
  final AutomaticSyncProbe _networkProbe;
  final AutomaticSyncEligibility _canSync;
  final AutomaticSyncMetricsReader _readMetrics;
  final bool automaticSchedulingEnabled;
  final Duration normalInterval;

  AutomaticSyncSnapshot _snapshot = const AutomaticSyncSnapshot();
  Future<void>? _activeRun;
  Timer? _scheduledRun;
  Timer? _completionTimer;
  bool _initialized = false;
  bool _disposed = false;
  int _eventId = 0;
  int _lastObservedPendingCount = 0;

  AutomaticSyncSnapshot get snapshot => _snapshot;

  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }

    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    AuthSessionStore.instance.addListener(_handleAuthenticationChanged);
    DirectoryDataStore.instance.addListener(_handleStoreChanged);

    final metrics = _readMetrics();
    _lastObservedPendingCount = metrics.pendingOperations;
    _setSnapshot(
      AutomaticSyncSnapshot(
        pendingOperations: metrics.pendingOperations,
        failedOperations: metrics.failedOperations,
        exhaustedOperations: metrics.exhaustedOperations,
        pendingConflicts: metrics.pendingConflicts,
      ),
    );

    _scheduleRun(
      AutomaticSyncTrigger.startup,
      delay: const Duration(milliseconds: 900),
    );
  }

  Future<void> runNow({
    AutomaticSyncTrigger trigger = AutomaticSyncTrigger.manual,
  }) {
    final existing = _activeRun;
    if (existing != null) {
      return existing;
    }

    _scheduledRun?.cancel();
    _scheduledRun = null;

    late final Future<void> operation;
    operation = _execute(trigger).whenComplete(() {
      if (identical(_activeRun, operation)) {
        _activeRun = null;
      }
    });
    _activeRun = operation;
    return operation;
  }

  Future<void> _execute(AutomaticSyncTrigger trigger) async {
    final before = _readMetrics();
    final startedAt = DateTime.now().toUtc();

    if (!_canSync()) {
      _setSnapshot(
        AutomaticSyncSnapshot(
          phase: AutomaticSyncPhase.idle,
          message: 'المزامنة التلقائية تنتظر تسجيل الدخول.',
          trigger: trigger,
          pendingOperations: before.pendingOperations,
          failedOperations: before.failedOperations,
          exhaustedOperations: before.exhaustedOperations,
          pendingConflicts: before.pendingConflicts,
          eventId: _eventId,
          lastStartedAt: startedAt,
          lastCompletedAt: _snapshot.lastCompletedAt,
        ),
      );
      return;
    }

    _setSnapshot(
      AutomaticSyncSnapshot(
        phase: AutomaticSyncPhase.checkingConnection,
        message: 'جارٍ التحقق من الاتصال قبل المزامنة.',
        trigger: trigger,
        pendingOperations: before.pendingOperations,
        failedOperations: before.failedOperations,
        pendingConflicts: before.pendingConflicts,
        consecutiveNetworkFailures: _snapshot.consecutiveNetworkFailures,
        eventId: _eventId,
        lastStartedAt: startedAt,
        lastCompletedAt: _snapshot.lastCompletedAt,
      ),
    );

    final isOnline = await _networkProbe();
    if (!isOnline) {
      final failureCount = _snapshot.consecutiveNetworkFailures + 1;
      final delay = AutomaticSyncRetryPolicy.delayForFailure(
        failureCount,
      );
      final nextRetryAt = DateTime.now().toUtc().add(delay);

      _setSnapshot(
        AutomaticSyncSnapshot(
          phase: AutomaticSyncPhase.offline,
          message: 'لا يوجد اتصال متاح؛ ستُستأنف المزامنة تلقائيًا.',
          trigger: trigger,
          pendingOperations: before.pendingOperations,
          failedOperations: before.failedOperations,
          exhaustedOperations: before.exhaustedOperations,
          pendingConflicts: before.pendingConflicts,
          consecutiveNetworkFailures: failureCount,
          eventId: ++_eventId,
          lastStartedAt: startedAt,
          lastCompletedAt: _snapshot.lastCompletedAt,
          nextRetryAt: nextRetryAt,
        ),
      );
      _scheduleRun(trigger, delay: delay);
      return;
    }

    _setSnapshot(
      AutomaticSyncSnapshot(
        phase: AutomaticSyncPhase.syncing,
        message: before.pendingOperations > 0
            ? 'جارٍ إرسال العمليات المحفوظة واستقبال التحديثات.'
            : 'جارٍ البحث عن تحديثات جديدة.',
        trigger: trigger,
        pendingOperations: before.pendingOperations,
        failedOperations: before.failedOperations,
        pendingConflicts: before.pendingConflicts,
        eventId: _eventId,
        lastStartedAt: startedAt,
        lastCompletedAt: _snapshot.lastCompletedAt,
      ),
    );

    Object? thrownError;
    try {
      await _syncAction();
    } catch (error, stackTrace) {
      thrownError = error;
      debugPrint('Automatic synchronization failed: $error\n$stackTrace');
    }

    final after = _readMetrics();
    final finishedAt = DateTime.now().toUtc();
    final effectiveError = thrownError ?? after.lastError;

    if (after.pendingConflicts > 0 || after.exhaustedOperations > 0) {
      _setSnapshot(
        AutomaticSyncSnapshot(
          phase: AutomaticSyncPhase.attentionRequired,
          message: after.pendingConflicts > 0
              ? 'اكتملت المحاولة، وتوجد تعارضات تحتاج إلى قرار.'
              : 'توجد عمليات متوقفة بعد استنفاد المحاولات.',
          trigger: trigger,
          pendingOperations: after.pendingOperations,
          failedOperations: after.failedOperations,
          exhaustedOperations: after.exhaustedOperations,
          pendingConflicts: after.pendingConflicts,
          eventId: ++_eventId,
          announce: true,
          lastStartedAt: startedAt,
          lastCompletedAt: finishedAt,
        ),
      );
      _scheduleRun(
        AutomaticSyncTrigger.periodic,
        delay: normalInterval,
      );
      return;
    }

    if (effectiveError != null) {
      final failureCount = _snapshot.consecutiveNetworkFailures + 1;
      final delay = AutomaticSyncRetryPolicy.delayForFailure(
        failureCount,
      );
      final nextRetryAt = finishedAt.add(delay);

      _setSnapshot(
        AutomaticSyncSnapshot(
          phase: AutomaticSyncPhase.waitingRetry,
          message: 'تعذرت المزامنة؛ ستتم إعادة المحاولة تلقائيًا.',
          trigger: trigger,
          pendingOperations: after.pendingOperations,
          failedOperations: after.failedOperations,
          exhaustedOperations: after.exhaustedOperations,
          pendingConflicts: after.pendingConflicts,
          consecutiveNetworkFailures: failureCount,
          eventId: ++_eventId,
          lastStartedAt: startedAt,
          lastCompletedAt: _snapshot.lastCompletedAt,
          nextRetryAt: nextRetryAt,
        ),
      );
      _scheduleRun(trigger, delay: delay);
      return;
    }

    if (after.pendingOperations > 0) {
      final nextRetryAt = finishedAt.add(normalInterval);
      _setSnapshot(
        AutomaticSyncSnapshot(
          phase: AutomaticSyncPhase.waitingRetry,
          message: 'بعض العمليات تنتظر موعد إعادة المحاولة التالي.',
          trigger: trigger,
          pendingOperations: after.pendingOperations,
          failedOperations: after.failedOperations,
          exhaustedOperations: after.exhaustedOperations,
          pendingConflicts: after.pendingConflicts,
          eventId: ++_eventId,
          lastStartedAt: startedAt,
          lastCompletedAt: finishedAt,
          nextRetryAt: nextRetryAt,
        ),
      );
      _scheduleRun(
        AutomaticSyncTrigger.periodic,
        delay: normalInterval,
      );
      return;
    }

    final announceCompletion = before.pendingOperations > 0;
    _setSnapshot(
      AutomaticSyncSnapshot(
        phase: AutomaticSyncPhase.completed,
        message: announceCompletion
            ? 'اكتملت مزامنة العمليات المحفوظة بنجاح.'
            : 'البيانات محدثة ولا توجد عمليات معلقة.',
        trigger: trigger,
        pendingOperations: 0,
        failedOperations: 0,
        pendingConflicts: 0,
        eventId: announceCompletion ? ++_eventId : _eventId,
        announce: announceCompletion,
        lastStartedAt: startedAt,
        lastCompletedAt: finishedAt,
      ),
    );

    _scheduleCompletionHide();
    _scheduleRun(
      AutomaticSyncTrigger.periodic,
      delay: normalInterval,
    );
  }

  void _handleAuthenticationChanged() {
    if (!_canSync()) {
      _scheduledRun?.cancel();
      _setSnapshot(const AutomaticSyncSnapshot(
        message: 'المزامنة التلقائية تنتظر تسجيل الدخول.',
      ));
      return;
    }

    _scheduleRun(
      AutomaticSyncTrigger.authentication,
      delay: const Duration(milliseconds: 400),
    );
  }

  void _handleStoreChanged() {
    final metrics = _readMetrics();
    final pendingIncreased =
        metrics.pendingOperations > _lastObservedPendingCount;
    _lastObservedPendingCount = metrics.pendingOperations;

    if (!_snapshot.isBusy) {
      _setSnapshot(
        AutomaticSyncSnapshot(
          phase: _snapshot.phase,
          message: _snapshot.message,
          trigger: _snapshot.trigger,
          pendingOperations: metrics.pendingOperations,
          failedOperations: metrics.failedOperations,
          exhaustedOperations: metrics.exhaustedOperations,
          pendingConflicts: metrics.pendingConflicts,
          consecutiveNetworkFailures: _snapshot.consecutiveNetworkFailures,
          eventId: _snapshot.eventId,
          announce: _snapshot.announce,
          lastStartedAt: _snapshot.lastStartedAt,
          lastCompletedAt: _snapshot.lastCompletedAt,
          nextRetryAt: _snapshot.nextRetryAt,
        ),
      );
    }

    if (pendingIncreased && _activeRun == null) {
      _scheduleRun(
        AutomaticSyncTrigger.queueChanged,
        delay: const Duration(milliseconds: 800),
      );
      unawaited(
        BackgroundSyncService.instance.scheduleOneOffSync(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleRun(
        AutomaticSyncTrigger.appResume,
        delay: const Duration(milliseconds: 300),
      );
      unawaited(BackgroundSyncSettingsStore.instance.reload());
      return;
    }

    if (state == AppLifecycleState.paused &&
        _readMetrics().pendingOperations > 0) {
      unawaited(
        BackgroundSyncService.instance.scheduleOneOffSync(
          initialDelay: const Duration(seconds: 15),
        ),
      );
    }
  }

  void _scheduleRun(
    AutomaticSyncTrigger trigger, {
    required Duration delay,
  }) {
    if (!automaticSchedulingEnabled || _disposed || !_canSync()) {
      return;
    }

    _scheduledRun?.cancel();
    _scheduledRun = Timer(delay, () {
      if (!_disposed) {
        unawaited(runNow(trigger: trigger));
      }
    });
  }

  void _scheduleCompletionHide() {
    _completionTimer?.cancel();
    _completionTimer = Timer(const Duration(seconds: 6), () {
      if (_snapshot.phase != AutomaticSyncPhase.completed || _disposed) {
        return;
      }

      final metrics = _readMetrics();
      _setSnapshot(
        AutomaticSyncSnapshot(
          pendingOperations: metrics.pendingOperations,
          failedOperations: metrics.failedOperations,
          exhaustedOperations: metrics.exhaustedOperations,
          pendingConflicts: metrics.pendingConflicts,
          lastCompletedAt: _snapshot.lastCompletedAt,
          eventId: _snapshot.eventId,
        ),
      );
    });
  }

  void _setSnapshot(AutomaticSyncSnapshot value) {
    if (_disposed) {
      return;
    }
    _snapshot = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _scheduledRun?.cancel();
    _completionTimer?.cancel();
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
      AuthSessionStore.instance.removeListener(
        _handleAuthenticationChanged,
      );
      DirectoryDataStore.instance.removeListener(_handleStoreChanged);
    }
    super.dispose();
  }
}
