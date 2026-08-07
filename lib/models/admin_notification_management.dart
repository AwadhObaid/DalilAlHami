enum AdminNotificationAudience {
  public,
  user;

  String get rpcValue => switch (this) {
        AdminNotificationAudience.public => 'public',
        AdminNotificationAudience.user => 'user',
      };

  String get label => switch (this) {
        AdminNotificationAudience.public => 'جميع مستخدمي التطبيق',
        AdminNotificationAudience.user => 'مستخدم محدد',
      };
}

enum AdminNotificationNavigation {
  notifications,
  home,
  categories,
  search,
  account,
  business;

  String get rpcValue => switch (this) {
        AdminNotificationNavigation.notifications => 'notifications',
        AdminNotificationNavigation.home => 'home',
        AdminNotificationNavigation.categories => 'categories',
        AdminNotificationNavigation.search => 'search',
        AdminNotificationNavigation.account => 'account',
        AdminNotificationNavigation.business => 'business',
      };

  String get label => switch (this) {
        AdminNotificationNavigation.notifications => 'مركز الإشعارات',
        AdminNotificationNavigation.home => 'الصفحة الرئيسية',
        AdminNotificationNavigation.categories => 'الأقسام',
        AdminNotificationNavigation.search => 'البحث',
        AdminNotificationNavigation.account => 'حسابي',
        AdminNotificationNavigation.business => 'تفاصيل نشاط',
      };
}

class AdminNotificationUserOption {
  const AdminNotificationUserOption({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
  });

  final String id;
  final String name;
  final String email;
  final String phone;

  String get secondaryLabel {
    if (email.trim().isNotEmpty) {
      return email.trim();
    }
    if (phone.trim().isNotEmpty) {
      return phone.trim();
    }
    return id;
  }

  factory AdminNotificationUserOption.fromMap(Map<String, dynamic> map) {
    return AdminNotificationUserOption(
      id: map['id']?.toString() ?? '',
      name: _displayName(map),
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
    );
  }

  static String _displayName(Map<String, dynamic> map) {
    final name = map['full_name']?.toString().trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    final email = map['email']?.toString().trim() ?? '';
    if (email.isNotEmpty) {
      return email;
    }
    final phone = map['phone']?.toString().trim() ?? '';
    return phone.isNotEmpty ? phone : 'مستخدم';
  }
}

class AdminNotificationHistoryItem {
  const AdminNotificationHistoryItem({
    required this.id,
    required this.title,
    required this.body,
    required this.targetType,
    required this.navigationType,
    required this.deliveryStatus,
    required this.attemptCount,
    required this.successCount,
    required this.createdAt,
    this.targetUserName,
    this.businessName,
    this.errorMessage,
  });

  final String id;
  final String title;
  final String body;
  final String targetType;
  final String navigationType;
  final String deliveryStatus;
  final int attemptCount;
  final int successCount;
  final DateTime createdAt;
  final String? targetUserName;
  final String? businessName;
  final String? errorMessage;

  factory AdminNotificationHistoryItem.fromMap(Map<String, dynamic> map) {
    return AdminNotificationHistoryItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      targetType: map['target_type']?.toString() ?? 'public',
      navigationType: map['navigation_type']?.toString() ?? 'notifications',
      deliveryStatus: map['delivery_status']?.toString() ?? 'pending',
      attemptCount: _integer(map['delivery_attempt_count']),
      successCount: _integer(map['delivery_success_count']),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      targetUserName: _nullableText(map['target_user_name']),
      businessName: _nullableText(map['business_name']),
      errorMessage: _nullableText(map['error_message']),
    );
  }

  static int _integer(Object? value) => int.tryParse('$value') ?? 0;

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class AdminNotificationSendResult {
  const AdminNotificationSendResult({
    required this.notificationId,
    required this.message,
    required this.deliveryStatus,
    required this.attemptCount,
    required this.successCount,
  });

  final String notificationId;
  final String message;
  final String deliveryStatus;
  final int attemptCount;
  final int successCount;

  factory AdminNotificationSendResult.fromMap(Map<String, dynamic> map) {
    return AdminNotificationSendResult(
      notificationId: map['notification_id']?.toString() ?? '',
      message: map['message']?.toString() ?? 'تم حفظ الإشعار.',
      deliveryStatus: map['delivery_status']?.toString() ?? 'sent',
      attemptCount: int.tryParse('${map['attempt_count']}') ?? 0,
      successCount: int.tryParse('${map['success_count']}') ?? 0,
    );
  }
}
