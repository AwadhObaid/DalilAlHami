import '../core/services/push_notification_intent.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.targetType,
    required this.navigationType,
    required this.createdAt,
    required this.isRead,
    this.businessId,
    this.data = const <String, dynamic>{},
  });

  final String id;
  final String title;
  final String body;
  final String targetType;
  final String navigationType;
  final String? businessId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;

  PushNotificationIntent? get intent {
    final payload = <String, dynamic>{
      ...data,
      'type': navigationType,
      if (businessId?.trim().isNotEmpty == true)
        'business_id': businessId!.trim(),
    };
    return PushNotificationIntent.fromData(payload);
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      targetType: targetType,
      navigationType: navigationType,
      businessId: businessId,
      data: data,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      targetType: map['target_type']?.toString() ?? 'public',
      navigationType: map['navigation_type']?.toString() ?? 'notifications',
      businessId: _nullableText(map['business_id']),
      data: _readMap(map['data']),
      createdAt: _readDate(map['created_at']),
      isRead: map['is_read'] == true,
    );
  }

  static Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        value.map((key, item) => MapEntry(key.toString(), item)),
      );
    }
    return const <String, dynamic>{};
  }

  static DateTime _readDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
