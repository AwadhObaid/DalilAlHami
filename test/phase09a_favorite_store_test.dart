import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/favorite_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await FavoriteStore.instance.initialize(reload: true);
    await FavoriteStore.instance.resetForTesting();
  });

  test('favorites persist locally without authentication', () async {
    const businessId = '11111111-1111-4111-8111-111111111111';

    expect(FavoriteStore.instance.isFavorite(businessId), isFalse);

    final selected = await FavoriteStore.instance.toggleFavorite(businessId);

    expect(selected, isTrue);
    expect(FavoriteStore.instance.isFavorite(businessId), isTrue);
    expect(FavoriteStore.instance.count, 1);

    await FavoriteStore.instance.initialize(reload: true);
    expect(FavoriteStore.instance.isFavorite(businessId), isTrue);

    final removed = await FavoriteStore.instance.toggleFavorite(businessId);

    expect(removed, isFalse);
    expect(FavoriteStore.instance.isFavorite(businessId), isFalse);
  });

  test('bundled non-UUID business ids remain valid local favorites', () async {
    const businessId = 'bundled-business-restaurant-1';

    await FavoriteStore.instance.toggleFavorite(businessId);

    expect(FavoriteStore.instance.isFavorite(businessId), isTrue);
    expect(FavoriteStore.instance.lastError, isNull);
  });
}
