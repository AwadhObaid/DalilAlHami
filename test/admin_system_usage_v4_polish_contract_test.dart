import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v4 system usage polish keeps RTL numbers and bucket fix contracts', () {
    final page = File(
      'lib/features/admin/admin_system_usage_page.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/data/repositories/admin_system_usage_repository.dart',
    ).readAsStringSync();
    final model = File(
      'lib/models/admin_system_usage.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/'
      '20260813184600_admin_system_bucket_usage_rpc.sql',
    ).readAsStringSync();

    expect(page, contains('unselectedLabelColor: Colors.white70'));
    expect(page, contains('indicatorColor: Colors.white'));
    expect(page, contains('textDirection: TextDirection.ltr'));
    expect(
      page,
      contains('تعذر تحميل توزيع الحاويات. اسحب للأسفل لإعادة القراءة.'),
    );

    expect(repository, contains("admin_system_bucket_usage"));
    expect(repository, contains('AdminBucketUsage.readList'));
    expect(model, contains('AdminSystemUsageSnapshot copyWith'));
    expect(model, contains('static List<AdminBucketUsage> readList'));

    expect(migration, contains('security invoker'));
    expect(migration, contains('admin_system_bucket_usage'));
    expect(migration, contains("('business-media'::text)"));
    expect(migration, contains("('advertisements'::text)"));
    expect(migration, contains("('avatars'::text)"));
    expect(migration, contains("('category-media'::text)"));
    expect(migration, isNot(contains('from storage.buckets')));
    expect(migration, contains('left join storage.objects object'));
  });
}
