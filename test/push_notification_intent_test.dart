import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/push_notification_intent.dart';

void main() {
  test('parses supported shell notification targets', () {
    expect(
      PushNotificationIntent.fromData(const {'type': 'home'})?.target,
      PushNotificationTarget.home,
    );
    expect(
      PushNotificationIntent.fromData(const {'type': 'categories'})?.target,
      PushNotificationTarget.categories,
    );
    expect(
      PushNotificationIntent.fromData(const {'type': 'search'})?.target,
      PushNotificationTarget.search,
    );
    expect(
      PushNotificationIntent.fromData(const {'type': 'account'})?.target,
      PushNotificationTarget.account,
    );
  });

  test('business notification requires a non-empty business id', () {
    final intent = PushNotificationIntent.fromData(
      const {'type': 'business', 'business_id': 'business-42'},
    );
    expect(intent?.target, PushNotificationTarget.business);
    expect(intent?.businessId, 'business-42');

    expect(
      PushNotificationIntent.fromData(const {'type': 'business'}),
      isNull,
    );
  });

  test('parses local notification JSON payload safely', () {
    final intent = PushNotificationIntent.fromPayload(
      '{"type":"business","business_id":"abc"}',
    );
    expect(intent?.target, PushNotificationTarget.business);
    expect(intent?.businessId, 'abc');
    expect(PushNotificationIntent.fromPayload('not-json'), isNull);
    expect(PushNotificationIntent.fromPayload(null), isNull);
  });

  test('rejects unknown notification targets', () {
    expect(
      PushNotificationIntent.fromData(const {'type': 'unknown'}),
      isNull,
    );
  });
}
