import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/favorite_store.dart';
import 'package:hami_guide/features/directory/widgets/business_favorite_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await FavoriteStore.instance.initialize(reload: true);
    await FavoriteStore.instance.resetForTesting();
  });

  testWidgets('favorite button toggles local state immediately', (tester) async {
    const businessId = '11111111-1111-4111-8111-111111111111';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BusinessFavoriteButton(businessId: businessId),
        ),
      ),
    );

    expect(FavoriteStore.instance.isFavorite(businessId), isFalse);

    await tester.tap(find.byKey(const ValueKey<String>(
      'favorite-toggle-11111111-1111-4111-8111-111111111111',
    )));
    await tester.pump();

    expect(FavoriteStore.instance.isFavorite(businessId), isTrue);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });
}
