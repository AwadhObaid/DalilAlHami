import 'dart:convert';
import 'dart:math';

const Object _unsetSyncQueueValue = Object();

enum SyncQueueEntityType {
  business;

  String get databaseValue => switch (this) {
        SyncQueueEntityType.business => 'business',
      };

  static SyncQueueEntityType fromDatabase(Object? value) {
    return switch (value?.toString()) {
      'business' => SyncQueueEntityType.business,
      _ => throw FormatException(
          'Unsupported sync queue entity type: $value',
        ),
    };
  }
}

enum SyncQueueOperationType {
  create,
  update,
  deleteEntity,
  submitForReview;

  String get databaseValue => switch (this) {
        SyncQueueOperationType.create => 'create',
        SyncQueueOperationType.update => 'update',
        SyncQueueOperationType.deleteEntity => 'delete',
        SyncQueueOperationType.submitForReview => 'submit_for_review',
      };

  String get label => switch (this) {
        SyncQueueOperationType.create => 'إضافة نشاط',
        SyncQueueOperationType.update => 'تعديل نشاط',
        SyncQueueOperationType.deleteEntity => 'حذف نشاط',
        SyncQueueOperationType.submitForReview => 'إرسال للمراجعة',
      };

  static SyncQueueOperationType fromDatabase(Object? value) {
    return switch (value?.toString()) {
      'create' => SyncQueueOperationType.create,
      'update' => SyncQueueOperationType.update,
      'delete' => SyncQueueOperationType.deleteEntity,
      'submit_for_review' => SyncQueueOperationType.submitForReview,
      _ => throw FormatException(
          'Unsupported sync queue operation type: $value',
        ),
    };
  }
}

enum SyncQueueStatus {
  pending,
  processing,
  completed,
  failed;

  String get databaseValue => name;

  String get label => switch (this) {
        SyncQueueStatus.pending => 'بانتظار المزامنة',
        SyncQueueStatus.processing => 'جارٍ الإرسال',
        SyncQueueStatus.completed => 'تمت المزامنة',
        SyncQueueStatus.failed => 'فشلت المزامنة',
      };

  static SyncQueueStatus fromDatabase(Object? value) {
    return switch (value?.toString()) {
      'pending' => SyncQueueStatus.pending,
      'processing' => SyncQueueStatus.processing,
      'completed' => SyncQueueStatus.completed,
      'failed' => SyncQueueStatus.failed,
      _ => throw FormatException(
          'Unsupported sync queue status: $value',
        ),
    };
  }
}

class SyncQueueOperationId {
  const SyncQueueOperationId._();

  static String create({
    DateTime? now,
    Random? random,
  }) {
    final timestamp = (now ?? DateTime.now())
        .toUtc()
        .microsecondsSinceEpoch
        .toRadixString(16);
    final generator = random ?? Random.secure();
    final entropy = List<int>.generate(
      4,
      (_) => generator.nextInt(0x7fffffff),
    ).map((value) => value.toRadixString(16).padLeft(8, '0')).join();

    return 'op-$timestamp-$entropy';
  }
}

class SyncQueueEnqueueRequest {
  factory SyncQueueEnqueueRequest({
    required String userId,
    required SyncQueueEntityType entityType,
    required SyncQueueOperationType operationType,
    required Map<String, dynamic> payload,
    String? operationId,
    String? deduplicationKey,
    String? entityId,
    int maxAttempts = 5,
    int priority = 0,
    DateTime? createdAt,
  }) {
    final resolvedOperationId = operationId ?? SyncQueueOperationId.create();

    return SyncQueueEnqueueRequest._(
      operationId: resolvedOperationId,
      deduplicationKey: deduplicationKey ?? resolvedOperationId,
      userId: userId,
      entityType: entityType,
      operationType: operationType,
      entityId: entityId,
      payload: payload,
      maxAttempts: maxAttempts,
      priority: priority,
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
    );
  }

  const SyncQueueEnqueueRequest._({
    required this.operationId,
    required this.deduplicationKey,
    required this.userId,
    required this.entityType,
    required this.operationType,
    required this.payload,
    required this.maxAttempts,
    required this.priority,
    required this.createdAt,
    this.entityId,
  });

  final String operationId;
  final String deduplicationKey;
  final String userId;
  final SyncQueueEntityType entityType;
  final SyncQueueOperationType operationType;
  final String? entityId;
  final Map<String, dynamic> payload;
  final int maxAttempts;
  final int priority;
  final DateTime createdAt;

  void validate() {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'Operation ID cannot be empty.',
      );
    }
    if (deduplicationKey.trim().isEmpty) {
      throw ArgumentError.value(
        deduplicationKey,
        'deduplicationKey',
        'Deduplication key cannot be empty.',
      );
    }
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(
        userId,
        'userId',
        'User ID cannot be empty.',
      );
    }
    if (maxAttempts < 1) {
      throw ArgumentError.value(
        maxAttempts,
        'maxAttempts',
        'Maximum attempts must be at least one.',
      );
    }

    if (operationType != SyncQueueOperationType.create &&
        (entityId == null || entityId!.trim().isEmpty)) {
      throw ArgumentError.value(
        entityId,
        'entityId',
        'Entity ID is required for this operation.',
      );
    }

    jsonEncode(payload);
  }
}

class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.deduplicationKey,
    required this.userId,
    required this.entityType,
    required this.operationType,
    required this.payload,
    required this.status,
    required this.attemptCount,
    required this.maxAttempts,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.entityId,
    this.nextAttemptAt,
    this.lastAttemptAt,
    this.completedAt,
    this.lastError,
    this.remoteResult,
  });

  final String id;
  final String deduplicationKey;
  final String userId;
  final SyncQueueEntityType entityType;
  final SyncQueueOperationType operationType;
  final String? entityId;
  final Map<String, dynamic> payload;
  final SyncQueueStatus status;
  final int attemptCount;
  final int maxAttempts;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? nextAttemptAt;
  final DateTime? lastAttemptAt;
  final DateTime? completedAt;
  final String? lastError;
  final Map<String, dynamic>? remoteResult;

  bool get isExhausted =>
      status == SyncQueueStatus.failed && attemptCount >= maxAttempts;

  bool get hasPendingWork =>
      status == SyncQueueStatus.pending ||
      status == SyncQueueStatus.processing ||
      (status == SyncQueueStatus.failed && !isExhausted);

  bool isDueAt(DateTime value) {
    if (!hasPendingWork || status == SyncQueueStatus.processing) {
      return false;
    }

    final next = nextAttemptAt;
    return next == null || !next.isAfter(value.toUtc());
  }

  SyncQueueItem copyWith({
    String? id,
    String? deduplicationKey,
    String? userId,
    SyncQueueEntityType? entityType,
    SyncQueueOperationType? operationType,
    Object? entityId = _unsetSyncQueueValue,
    Map<String, dynamic>? payload,
    SyncQueueStatus? status,
    int? attemptCount,
    int? maxAttempts,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? nextAttemptAt = _unsetSyncQueueValue,
    Object? lastAttemptAt = _unsetSyncQueueValue,
    Object? completedAt = _unsetSyncQueueValue,
    Object? lastError = _unsetSyncQueueValue,
    Object? remoteResult = _unsetSyncQueueValue,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      deduplicationKey: deduplicationKey ?? this.deduplicationKey,
      userId: userId ?? this.userId,
      entityType: entityType ?? this.entityType,
      operationType: operationType ?? this.operationType,
      entityId: identical(entityId, _unsetSyncQueueValue)
          ? this.entityId
          : entityId as String?,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextAttemptAt: identical(
        nextAttemptAt,
        _unsetSyncQueueValue,
      )
          ? this.nextAttemptAt
          : nextAttemptAt as DateTime?,
      lastAttemptAt: identical(
        lastAttemptAt,
        _unsetSyncQueueValue,
      )
          ? this.lastAttemptAt
          : lastAttemptAt as DateTime?,
      completedAt: identical(
        completedAt,
        _unsetSyncQueueValue,
      )
          ? this.completedAt
          : completedAt as DateTime?,
      lastError: identical(lastError, _unsetSyncQueueValue)
          ? this.lastError
          : lastError as String?,
      remoteResult: identical(
        remoteResult,
        _unsetSyncQueueValue,
      )
          ? this.remoteResult
          : remoteResult as Map<String, dynamic>?,
    );
  }

  Map<String, Object?> toDatabaseRow() {
    return {
      'id': id,
      'deduplication_key': deduplicationKey,
      'user_id': userId,
      'entity_type': entityType.databaseValue,
      'entity_id': entityId,
      'operation_type': operationType.databaseValue,
      'payload_json': jsonEncode(payload),
      'status': status.databaseValue,
      'attempt_count': attemptCount,
      'max_attempts': maxAttempts,
      'priority': priority,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'next_attempt_at': nextAttemptAt?.toUtc().toIso8601String(),
      'last_attempt_at': lastAttemptAt?.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'last_error': lastError,
      'remote_result_json':
          remoteResult == null ? null : jsonEncode(remoteResult),
    };
  }

  factory SyncQueueItem.fromDatabaseRow(
    Map<String, Object?> row,
  ) {
    return SyncQueueItem(
      id: row['id']?.toString() ?? '',
      deduplicationKey: row['deduplication_key']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      entityType: SyncQueueEntityType.fromDatabase(
        row['entity_type'],
      ),
      entityId: _nullableText(row['entity_id']),
      operationType: SyncQueueOperationType.fromDatabase(
        row['operation_type'],
      ),
      payload: _decodeMap(row['payload_json']),
      status: SyncQueueStatus.fromDatabase(row['status']),
      attemptCount: _readInteger(row['attempt_count']),
      maxAttempts: _readInteger(row['max_attempts'], fallback: 5),
      priority: _readInteger(row['priority']),
      createdAt: _readDate(row['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: _readDate(row['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      nextAttemptAt: _readDate(row['next_attempt_at']),
      lastAttemptAt: _readDate(row['last_attempt_at']),
      completedAt: _readDate(row['completed_at']),
      lastError: _nullableText(row['last_error']),
      remoteResult: _decodeNullableMap(
        row['remote_result_json'],
      ),
    );
  }

  static Map<String, dynamic> _decodeMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(value),
      );
    }

    final source = value?.toString() ?? '{}';
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'Sync queue payload must be a JSON object.',
      );
    }

    return Map<String, dynamic>.unmodifiable(
      Map<String, dynamic>.from(decoded),
    );
  }

  static Map<String, dynamic>? _decodeNullableMap(Object? value) {
    final text = _nullableText(value);
    return text == null ? null : _decodeMap(text);
  }

  static DateTime? _readDate(Object? value) {
    final text = _nullableText(value);
    return text == null ? null : DateTime.tryParse(text)?.toUtc();
  }

  static int _readInteger(Object? value, {int fallback = 0}) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class SyncQueueSummary {
  const SyncQueueSummary({
    this.total = 0,
    this.pending = 0,
    this.processing = 0,
    this.completed = 0,
    this.failed = 0,
    this.exhausted = 0,
  });

  final int total;
  final int pending;
  final int processing;
  final int completed;
  final int failed;
  final int exhausted;

  int get retryableFailed {
    final value = failed - exhausted;
    return value < 0 ? 0 : value;
  }

  int get actionable => pending + processing + retryableFailed;

  bool get hasPendingWork => actionable > 0;

  static SyncQueueSummary fromAggregateRow(
    Map<String, Object?> row,
  ) {
    int read(String key) {
      final value = row[key];
      if (value is num) {
        return value.toInt();
      }
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return SyncQueueSummary(
      total: read('total'),
      pending: read('pending'),
      processing: read('processing'),
      completed: read('completed'),
      failed: read('failed'),
      exhausted: read('exhausted'),
    );
  }
}
