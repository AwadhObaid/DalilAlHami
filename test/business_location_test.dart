import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/location/business_location.dart';

void main() {
  test('يبني موقعًا صالحًا ويعرض الإحداثيات', () {
    const location = BusinessLocation(
      latitude: 14.80933,
      longitude: 49.82983,
    );

    expect(location.coordinatesLabel, '14.809330, 49.829830');
    expect(
      BusinessLocation.fromNullable('14.80933', '49.82983'),
      location,
    );
  });

  test('يرفض الزوج الناقص أو الإحداثيات خارج النطاق', () {
    expect(
      () => BusinessLocation.validatePair(14.8, null),
      throwsArgumentError,
    );
    expect(
      () => BusinessLocation.validatePair(91, 49.8),
      throwsArgumentError,
    );
    expect(
      BusinessLocation.fromNullable('not-a-number', 49.8),
      isNull,
    );
  });
}
