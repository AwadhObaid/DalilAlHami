import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 09B database contract enforces one 1-to-5 rating per user', () {
    final migration = File(
      'supabase/migrations/20260808161000_phase09b_business_ratings.sql',
    ).readAsStringSync();

    expect(migration, contains('create table if not exists public.business_ratings'));
    expect(migration, contains('primary key (user_id, business_id)'));
    expect(migration, contains('check (rating between 1 and 5)'));
    expect(migration, contains('get_business_rating_summary'));
    expect(migration, contains('set_business_rating'));
    expect(migration, contains('public.is_active_account()'));
    expect(migration, contains("business.status = 'approved'"));
    expect(migration, contains('grant execute on function public.get_business_rating_summary(uuid) to anon'));
  });

  test('Phase 09B app wiring keeps ratings in details and startup sync', () {
    final main = File('lib/main.dart').readAsStringSync();
    final details = File(
      'lib/features/directory/member_details_page.dart',
    ).readAsStringSync();
    final widget = File(
      'lib/features/directory/widgets/business_rating_section.dart',
    ).readAsStringSync();
    final store = File(
      'lib/core/services/business_rating_store.dart',
    ).readAsStringSync();

    expect(main, contains('BusinessRatingStore.instance.initialize()'));
    expect(details, contains('BusinessRatingSection(businessId: business.id)'));
    expect(widget, contains('business-rating-star-'));
    expect(widget, contains('business-rating-pending'));
    expect(store, contains('phase09.rating.pending.v1'));
    expect(store, contains("rpc(\n        'set_business_rating'"));
  });
}
