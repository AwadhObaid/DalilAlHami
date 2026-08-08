import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/business_rating_store.dart';
import 'package:hami_guide/features/directory/widgets/business_rating_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await BusinessRatingStore.instance.initialize(reload: true);
    await BusinessRatingStore.instance.resetForTesting();
  });

  testWidgets('rating section renders five star actions without overflow', (
    tester,
  ) async {
    const businessId = '11111111-1111-4111-8111-111111111111';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BusinessRatingSection(businessId: businessId),
          ),
        ),
      ),
    );
    await tester.pump();

    for (var star = 1; star <= 5; star++) {
      expect(
        find.byKey(ValueKey<String>('business-rating-star-$star')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
