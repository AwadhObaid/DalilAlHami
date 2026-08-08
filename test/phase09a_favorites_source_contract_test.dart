import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 09A favorites source and Supabase contracts are present', () {
    final store = File('lib/core/services/favorite_store.dart').readAsStringSync();
    final button = File(
      'lib/features/directory/widgets/business_favorite_button.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/profile/favorite_businesses_page.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260808124500_phase09a_favorites_hardening.sql',
    ).readAsStringSync();

    expect(store, contains('phase09.favorite_ids.v1'));
    expect(store, contains("from('favorites')"));
    expect(store, contains('syncWithRemote'));
    expect(button, contains('favorite-toggle-'));
    expect(page, contains('favorites-business-list'));
    expect(page, contains('favorites-empty-list'));

    expect(migration, contains('favorites_select_own'));
    expect(migration, contains('favorites_insert_own_active'));
    expect(migration, contains('public.is_active_account()'));
    expect(migration, contains("business.status = 'approved'"));
  });

  test('Phase 09A integrates favorites into primary business surfaces', () {
    final home = File(
      'lib/features/home/widgets/home_business_card.dart',
    ).readAsStringSync();
    final card = File(
      'lib/features/directory/widgets/business_card.dart',
    ).readAsStringSync();
    final details = File(
      'lib/features/directory/member_details_page.dart',
    ).readAsStringSync();
    final account = File(
      'lib/features/profile/account_hub_page.dart',
    ).readAsStringSync();

    expect(home, contains('BusinessFavoriteButton'));
    expect(card, contains('BusinessFavoriteButton'));
    expect(details, contains('BusinessFavoriteButton'));
    expect(account, contains('FavoriteBusinessesPage'));
    expect(account, contains("'المفضلة'"));
  });
}
