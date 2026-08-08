import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/business_rating_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await BusinessRatingStore.instance.initialize(reload: true);
    await BusinessRatingStore.instance.resetForTesting();
  });

  test('rating store starts with an empty public summary', () {
    const businessId = '11111111-1111-4111-8111-111111111111';
    final snapshot = BusinessRatingStore.instance.snapshotFor(businessId);

    expect(snapshot.averageRating, 0);
    expect(snapshot.ratingsCount, 0);
    expect(snapshot.userRating, isNull);
    expect(snapshot.hasPendingRating, isFalse);
  });

  test('rating rejects non UUID businesses before remote mutation', () async {
    final result = await BusinessRatingStore.instance.setRating(
      'bundled-business-1',
      5,
    );

    expect(result, BusinessRatingSubmitResult.invalidBusiness);
  });

  test('rating validates the 1 to 5 range', () async {
    const businessId = '11111111-1111-4111-8111-111111111111';

    final result = await BusinessRatingStore.instance.setRating(businessId, 6);

    expect(result, BusinessRatingSubmitResult.invalidRating);
  });
}
