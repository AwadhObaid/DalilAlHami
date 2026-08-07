import 'dart:convert';

enum PushNotificationTarget {
  home,
  categories,
  search,
  account,
  business,
}

class PushNotificationIntent {
  const PushNotificationIntent._({
    required this.target,
    this.businessId,
  });

  const PushNotificationIntent.home()
      : this._(target: PushNotificationTarget.home);

  const PushNotificationIntent.categories()
      : this._(target: PushNotificationTarget.categories);

  const PushNotificationIntent.search()
      : this._(target: PushNotificationTarget.search);

  const PushNotificationIntent.account()
      : this._(target: PushNotificationTarget.account);

  const PushNotificationIntent.business(String businessId)
      : this._(
          target: PushNotificationTarget.business,
          businessId: businessId,
        );

  final PushNotificationTarget target;
  final String? businessId;

  static PushNotificationIntent? fromData(Map<String, dynamic> data) {
    final type =
        (data['type'] ?? data['target'])?.toString().trim().toLowerCase();

    return switch (type) {
      'home' => const PushNotificationIntent.home(),
      'categories' => const PushNotificationIntent.categories(),
      'search' => const PushNotificationIntent.search(),
      'account' || 'profile' => const PushNotificationIntent.account(),
      'business' => _businessIntent(data),
      _ => null,
    };
  }

  static PushNotificationIntent? fromPayload(String? payload) {
    final value = payload?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        return null;
      }
      return fromData(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static PushNotificationIntent? _businessIntent(
    Map<String, dynamic> data,
  ) {
    final id = (data['business_id'] ?? data['businessId'])?.toString().trim();
    if (id == null || id.isEmpty) {
      return null;
    }
    return PushNotificationIntent.business(id);
  }
}
