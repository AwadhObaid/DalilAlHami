import 'dart:convert';

import 'sync_queue_item.dart';

enum SyncConflictStatus {
  pending,
  resolvedKeepLocal,
  resolvedUseServer;

  String get databaseValue => switch (this) {
        SyncConflictStatus.pending => 'pending',
        SyncConflictStatus.resolvedKeepLocal => 'resolved_keep_local',
        SyncConflictStatus.resolvedUseServer => 'resolved_use_server',
      };

  String get label => switch (this) {
        SyncConflictStatus.pending => 'تعارض يحتاج قرارًا',
        SyncConflictStatus.resolvedKeepLocal => 'تم اعتماد تعديلاتك',
        SyncConflictStatus.resolvedUseServer => 'تم اعتماد نسخة الخادم',
      };

  bool get isPending => this == SyncConflictStatus.pending;

  static SyncConflictStatus fromDatabase(Object? value) {
    return switch (value?.toString()) {
      'pending' => SyncConflictStatus.pending,
      'resolved_keep_local' => SyncConflictStatus.resolvedKeepLocal,
      'resolved_use_server' => SyncConflictStatus.resolvedUseServer,
      _ => throw FormatException(
          'Unsupported sync conflict status: $value',
        ),
    };
  }
}

class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.operationId,
    required this.userId,
    required this.entityType,
    required this.operationType,
    required this.entityId,
    required this.localPayload,
    required this.serverSnapshot,
    required this.expectedSyncVersion,
    required this.serverSyncVersion,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.resolutionOperationId,
  });

  final String id;
  final String operationId;
  final String userId;
  final SyncQueueEntityType entityType;
  final SyncQueueOperationType operationType;
  final String entityId;
  final Map<String, dynamic> localPayload;
  final Map<String, dynamic> serverSnapshot;
  final int expectedSyncVersion;
  final int serverSyncVersion;
  final SyncConflictStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final String? resolutionOperationId;

  bool get isPending => status.isPending;

  String get entityName {
    final serverName = serverSnapshot['name']?.toString().trim();
    if (serverName != null && serverName.isNotEmpty) {
      return serverName;
    }
    final localName = localPayload['name']?.toString().trim();
    return localName == null || localName.isEmpty ? 'النشاط' : localName;
  }

  Map<String, Object?> toDatabaseRow() {
    return <String, Object?>{
      'id': id,
      'operation_id': operationId,
      'user_id': userId,
      'entity_type': entityType.databaseValue,
      'operation_type': operationType.databaseValue,
      'entity_id': entityId,
      'local_payload_json': jsonEncode(localPayload),
      'server_snapshot_json': jsonEncode(serverSnapshot),
      'expected_sync_version': expectedSyncVersion,
      'server_sync_version': serverSyncVersion,
      'status': status.databaseValue,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'resolved_at': resolvedAt?.toUtc().toIso8601String(),
      'resolution_operation_id': resolutionOperationId,
    };
  }

  factory SyncConflict.fromDatabaseRow(Map<String, Object?> row) {
    return SyncConflict(
      id: row['id']?.toString() ?? '',
      operationId: row['operation_id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      entityType: SyncQueueEntityType.fromDatabase(row['entity_type']),
      operationType: SyncQueueOperationType.fromDatabase(
        row['operation_type'],
      ),
      entityId: row['entity_id']?.toString() ?? '',
      localPayload: _decodeMap(row['local_payload_json']),
      serverSnapshot: _decodeMap(row['server_snapshot_json']),
      expectedSyncVersion: _readInteger(row['expected_sync_version']),
      serverSyncVersion: _readInteger(row['server_sync_version']),
      status: SyncConflictStatus.fromDatabase(row['status']),
      createdAt: _readDate(row['created_at']),
      updatedAt: _readDate(row['updated_at']),
      resolvedAt: _readNullableDate(row['resolved_at']),
      resolutionOperationId: _nullableText(
        row['resolution_operation_id'],
      ),
    );
  }

  SyncConflict copyWith({
    SyncConflictStatus? status,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    String? resolutionOperationId,
  }) {
    return SyncConflict(
      id: id,
      operationId: operationId,
      userId: userId,
      entityType: entityType,
      operationType: operationType,
      entityId: entityId,
      localPayload: localPayload,
      serverSnapshot: serverSnapshot,
      expectedSyncVersion: expectedSyncVersion,
      serverSyncVersion: serverSyncVersion,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionOperationId:
          resolutionOperationId ?? this.resolutionOperationId,
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

    final decoded = jsonDecode(value?.toString() ?? '{}');
    if (decoded is! Map) {
      throw const FormatException(
        'Sync conflict snapshot must be a JSON object.',
      );
    }
    return Map<String, dynamic>.unmodifiable(
      Map<String, dynamic>.from(decoded),
    );
  }

  static int _readInteger(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _readDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static DateTime? _readNullableDate(Object? value) {
    final text = _nullableText(value);
    return text == null ? null : DateTime.tryParse(text)?.toUtc();
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
