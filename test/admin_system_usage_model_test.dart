import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/models/admin_system_usage.dart';

void main() {
  test('admin system usage snapshot parses Supabase JSON safely', () {
    final snapshot = AdminSystemUsageSnapshot.fromRpc(<String, dynamic>{
      'captured_at': '2026-08-13T13:43:01.414709',
      'database_bytes': 13782163,
      'storage_bytes': 1883446,
      'counts': <String, dynamic>{
        'registered_users': 2,
        'active_users': 2,
        'businesses': 0,
        'advertisements': 1,
      },
      'bucket_usage': <Map<String, dynamic>>[
        <String, dynamic>{
          'bucket_id': 'advertisements',
          'file_count': 4,
          'bytes': 719887,
        },
      ],
      'table_usage': <Map<String, dynamic>>[
        <String, dynamic>{
          'table_name': 'categories',
          'row_count': 25,
          'bytes': 131072,
        },
      ],
      'top_files': <Map<String, dynamic>>[
        <String, dynamic>{
          'bucket_id': 'advertisements',
          'name': 'admin/ad.jpg',
          'bytes': 273804,
          'created_at': '2026-08-12T14:24:29.5782+00:00',
        },
      ],
    });

    expect(snapshot.databaseBytes, 13782163);
    expect(snapshot.storageBytes, 1883446);
    expect(snapshot.count('registered_users'), 2);
    expect(snapshot.bucketUsage.single.bucketId, 'advertisements');
    expect(snapshot.tableUsage.single.rowCount, 25);
    expect(snapshot.topFiles.single.fileName, 'ad.jpg');
    expect(snapshot.capturedAt.isUtc, isTrue);
  });

  test('unexpected RPC payload is rejected instead of silently guessing', () {
    expect(
      () => AdminSystemUsageSnapshot.fromRpc('bad-payload'),
      throwsFormatException,
    );
  });

  test('bucket usage helper payload parses all known buckets', () {
    final buckets = AdminBucketUsage.readList(<Map<String, dynamic>>[
      <String, dynamic>{
        'bucket_id': 'business-media',
        'file_count': 14,
        'bytes': 2658008,
      },
      <String, dynamic>{
        'bucket_id': 'advertisements',
        'file_count': 4,
        'bytes': 719887,
      },
      <String, dynamic>{
        'bucket_id': 'avatars',
        'file_count': 3,
        'bytes': 431501,
      },
      <String, dynamic>{
        'bucket_id': 'category-media',
        'file_count': 0,
        'bytes': 0,
      },
    ]);

    expect(buckets, hasLength(4));
    expect(buckets.first.bucketId, 'business-media');
    expect(buckets.last.bucketId, 'category-media');
  });
}
