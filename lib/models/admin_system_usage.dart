class AdminSystemUsageSnapshot {
  const AdminSystemUsageSnapshot({
    required this.capturedAt,
    required this.databaseBytes,
    required this.storageBytes,
    required this.bucketUsage,
    required this.tableUsage,
    required this.topFiles,
    required this.counts,
  });

  final DateTime capturedAt;
  final int databaseBytes;
  final int storageBytes;
  final List<AdminBucketUsage> bucketUsage;
  final List<AdminTableUsage> tableUsage;
  final List<AdminStorageFileUsage> topFiles;
  final Map<String, int> counts;

  AdminSystemUsageSnapshot copyWith({
    List<AdminBucketUsage>? bucketUsage,
  }) {
    return AdminSystemUsageSnapshot(
      capturedAt: capturedAt,
      databaseBytes: databaseBytes,
      storageBytes: storageBytes,
      bucketUsage: bucketUsage ?? this.bucketUsage,
      tableUsage: tableUsage,
      topFiles: topFiles,
      counts: counts,
    );
  }

  int count(String key) => counts[key] ?? 0;

  factory AdminSystemUsageSnapshot.fromRpc(Object? value) {
    final map = _readRootMap(value);
    return AdminSystemUsageSnapshot(
      capturedAt: _readUtcDate(map['captured_at']),
      databaseBytes: _readInt(map['database_bytes']),
      storageBytes: _readInt(map['storage_bytes']),
      bucketUsage: _readList(map['bucket_usage'])
          .map(AdminBucketUsage.fromMap)
          .toList(growable: false),
      tableUsage: _readList(map['table_usage'])
          .map(AdminTableUsage.fromMap)
          .toList(growable: false),
      topFiles: _readList(map['top_files'])
          .map(AdminStorageFileUsage.fromMap)
          .toList(growable: false),
      counts: Map<String, int>.unmodifiable(
        _readMap(map['counts']).map(
          (key, item) => MapEntry(key, _readInt(item)),
        ),
      ),
    );
  }

  static Map<String, dynamic> _readRootMap(Object? value) {
    if (value is Map) {
      return _readMap(value);
    }
    if (value is List && value.isNotEmpty && value.first is Map) {
      return _readMap(value.first);
    }
    throw const FormatException(
      'أعاد Supabase بيانات غير متوقعة لمراقبة النظام.',
    );
  }

  static Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _readList(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value.whereType<Map>().map(_readMap).toList(growable: false);
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _readUtcDate(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    final hasExplicitZone =
        raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);
    final normalized = hasExplicitZone ? raw : '${raw}Z';
    return DateTime.tryParse(normalized)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}

class AdminBucketUsage {
  const AdminBucketUsage({
    required this.bucketId,
    required this.fileCount,
    required this.bytes,
  });

  final String bucketId;
  final int fileCount;
  final int bytes;

  factory AdminBucketUsage.fromMap(Map<String, dynamic> map) {
    return AdminBucketUsage(
      bucketId: map['bucket_id']?.toString() ?? '',
      fileCount: _usageInt(map['file_count']),
      bytes: _usageInt(map['bytes']),
    );
  }

  static List<AdminBucketUsage> readList(Object? value) {
    if (value is! List) {
      return const <AdminBucketUsage>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => AdminBucketUsage.fromMap(
            item.map(
              (key, nestedValue) => MapEntry(key.toString(), nestedValue),
            ),
          ),
        )
        .where((item) => item.bucketId.isNotEmpty)
        .toList(growable: false);
  }
}

class AdminTableUsage {
  const AdminTableUsage({
    required this.tableName,
    required this.rowCount,
    required this.bytes,
  });

  final String tableName;
  final int rowCount;
  final int bytes;

  factory AdminTableUsage.fromMap(Map<String, dynamic> map) {
    return AdminTableUsage(
      tableName: map['table_name']?.toString() ?? '',
      rowCount: _usageInt(map['row_count']),
      bytes: _usageInt(map['bytes']),
    );
  }
}

class AdminStorageFileUsage {
  const AdminStorageFileUsage({
    required this.bucketId,
    required this.name,
    required this.bytes,
    required this.createdAt,
  });

  final String bucketId;
  final String name;
  final int bytes;
  final DateTime createdAt;

  String get fileName {
    final parts = name.split('/');
    return parts.isEmpty ? name : parts.last;
  }

  factory AdminStorageFileUsage.fromMap(Map<String, dynamic> map) {
    final rawDate = map['created_at']?.toString() ?? '';
    return AdminStorageFileUsage(
      bucketId: map['bucket_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      bytes: _usageInt(map['bytes']),
      createdAt: DateTime.tryParse(rawDate)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

int _usageInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
