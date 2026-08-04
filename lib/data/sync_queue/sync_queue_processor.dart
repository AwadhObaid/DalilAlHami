import '../local/database/local_directory_database.dart';
import 'sync_queue_remote_gateway.dart';

class SyncQueueBackoff {
  const SyncQueueBackoff._();

  static Duration delayForAttempt(int attemptCount) {
    return switch (attemptCount) {
      <= 1 => const Duration(seconds: 30),
      2 => const Duration(minutes: 2),
      3 => const Duration(minutes: 10),
      4 => const Duration(minutes: 30),
      _ => const Duration(hours: 2),
    };
  }
}

class SyncQueueProcessReport {
  const SyncQueueProcessReport({
    required this.startedAt,
    required this.finishedAt,
    this.claimed = 0,
    this.completed = 0,
    this.failed = 0,
    this.exhausted = 0,
    this.skipped = 0,
    this.lastError,
  });

  final DateTime startedAt;
  final DateTime finishedAt;
  final int claimed;
  final int completed;
  final int failed;
  final int exhausted;
  final int skipped;
  final Object? lastError;

  bool get hasWork => claimed > 0;

  bool get isSuccessful => failed == 0 && exhausted == 0;
}

class SyncQueueProcessor {
  SyncQueueProcessor({
    required LocalDirectoryDatabase database,
    required SyncQueueRemoteGateway gateway,
    required String userId,
    DateTime Function()? clock,
  })  : _database = database,
        _gateway = gateway,
        _userId = userId,
        _clock = clock ?? DateTime.now;

  final LocalDirectoryDatabase _database;
  final SyncQueueRemoteGateway _gateway;
  final String _userId;
  final DateTime Function() _clock;

  Future<SyncQueueProcessReport>? _activeProcess;

  Future<SyncQueueProcessReport> processPending({
    int limit = 20,
  }) {
    final existing = _activeProcess;
    if (existing != null) {
      return existing;
    }

    late final Future<SyncQueueProcessReport> operation;
    operation = _processPending(limit: limit).whenComplete(() {
      if (identical(_activeProcess, operation)) {
        _activeProcess = null;
      }
    });
    _activeProcess = operation;
    return operation;
  }

  Future<SyncQueueProcessReport> _processPending({
    required int limit,
  }) async {
    if (limit < 1) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Queue processing limit must be positive.',
      );
    }

    final startedAt = _clock().toUtc();
    await _database.recoverInterruptedSyncOperations(
      userId: _userId,
      now: startedAt,
      processingTimeout: const Duration(minutes: 5),
    );

    final candidates = await _database.readDueSyncOperations(
      userId: _userId,
      now: startedAt,
      limit: limit,
    );

    var claimedCount = 0;
    var completedCount = 0;
    var failedCount = 0;
    var exhaustedCount = 0;
    var skippedCount = 0;
    Object? lastError;

    for (final candidate in candidates) {
      final attemptStartedAt = _clock().toUtc();
      final claimed = await _database.claimSyncOperation(
        candidate.id,
        userId: _userId,
        now: attemptStartedAt,
      );

      if (claimed == null) {
        skippedCount++;
        continue;
      }

      claimedCount++;

      try {
        final result = await _gateway.execute(claimed);
        await _database.markSyncOperationCompleted(
          claimed.id,
          userId: _userId,
          completedAt: _clock().toUtc(),
          remoteResult: result.raw,
        );
        completedCount++;
      } catch (error) {
        lastError = error;
        final retryable =
            error is! SyncQueueExecutionException || error.isRetryable;
        final exhausted =
            !retryable || claimed.attemptCount >= claimed.maxAttempts;
        final failedAt = _clock().toUtc();
        final nextAttemptAt = exhausted
            ? null
            : failedAt.add(
                SyncQueueBackoff.delayForAttempt(
                  claimed.attemptCount,
                ),
              );

        await _database.markSyncOperationFailed(
          claimed.id,
          userId: _userId,
          failedAt: failedAt,
          error: error,
          nextAttemptAt: nextAttemptAt,
          exhaust: exhausted,
        );

        failedCount++;
        if (exhausted) {
          exhaustedCount++;
        }
      }
    }

    return SyncQueueProcessReport(
      startedAt: startedAt,
      finishedAt: _clock().toUtc(),
      claimed: claimedCount,
      completed: completedCount,
      failed: failedCount,
      exhausted: exhaustedCount,
      skipped: skippedCount,
      lastError: lastError,
    );
  }
}
