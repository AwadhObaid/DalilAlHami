import 'sync_queue_item.dart';

abstract interface class SyncQueueRemoteGateway {
  Future<SyncQueueRemoteResult> execute(SyncQueueItem item);
}

class SyncQueueExecutionException implements Exception {
  const SyncQueueExecutionException({
    required this.message,
    required this.isRetryable,
    this.code,
    this.cause,
  });

  final String message;
  final bool isRetryable;
  final String? code;
  final Object? cause;

  @override
  String toString() {
    final codeSuffix = code == null ? '' : ' ($code)';
    return 'SyncQueueExecutionException$codeSuffix: $message';
  }
}

class SyncQueueRemoteResult {
  const SyncQueueRemoteResult({
    required this.operationId,
    required this.operationType,
    required this.remoteStatus,
    required this.raw,
    this.entityId,
    this.replayed = false,
  });

  final String operationId;
  final String operationType;
  final String? entityId;
  final String remoteStatus;
  final bool replayed;
  final Map<String, dynamic> raw;

  factory SyncQueueRemoteResult.fromRpc(Object? response) {
    final map = _readMap(response);

    return SyncQueueRemoteResult(
      operationId: map['operation_id']?.toString() ?? '',
      operationType: map['operation_type']?.toString() ?? '',
      entityId: _nullableText(map['entity_id']),
      remoteStatus: map['remote_status']?.toString() ?? 'processed',
      replayed: _readBoolean(map['replayed']),
      raw: Map<String, dynamic>.unmodifiable(map),
    );
  }

  static Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const FormatException(
      'Supabase sync queue returned an invalid response.',
    );
  }

  static bool _readBoolean(Object? value) {
    return value == true || value == 1 || value?.toString() == '1';
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
