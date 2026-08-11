import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../models/app_notification.dart';

class NotificationRepository {
  const NotificationRepository();

  SupabaseClient get _client => SupabaseService.client;

  Future<List<AppNotification>> loadMyNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    _requireSession();
    try {
      final response = await _client.rpc(
        'list_my_notifications',
        params: <String, dynamic>{
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      final rows = response is List ? response : const <Object?>[];
      return rows
          .whereType<Map>()
          .map(
            (row) => AppNotification.fromMap(
              row.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw NotificationRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<int> unreadCount() async {
    if (!SupabaseService.isInitialized || _client.auth.currentUser == null) {
      return 0;
    }
    try {
      final response = await _client.rpc('my_notification_unread_count');
      return int.tryParse('$response') ?? 0;
    } on PostgrestException catch (error) {
      throw NotificationRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<bool> markRead(String notificationId) async {
    _requireSession();
    try {
      final response = await _client.rpc(
        'mark_my_notification_read',
        params: <String, dynamic>{
          'p_notification_id': notificationId,
        },
      );
      return response == true;
    } on PostgrestException catch (error) {
      throw NotificationRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<int> markAllRead() async {
    _requireSession();
    try {
      final response = await _client.rpc('mark_all_my_notifications_read');
      return int.tryParse('$response') ?? 0;
    } on PostgrestException catch (error) {
      throw NotificationRepositoryFailure(_friendlyMessage(error));
    }
  }

  Future<bool> dismiss(String notificationId) async {
    _requireSession();
    try {
      final response = await _client.rpc(
        'dismiss_my_notification',
        params: <String, dynamic>{
          'p_notification_id': notificationId,
        },
      );
      return response == true;
    } on PostgrestException catch (error) {
      throw NotificationRepositoryFailure(_friendlyMutationMessage(error));
    }
  }

  Future<int> dismissMany(List<String> notificationIds) async {
    _requireSession();
    final ids = notificationIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) {
      return 0;
    }

    try {
      final response = await _client.rpc(
        'dismiss_my_notifications',
        params: <String, dynamic>{
          'p_notification_ids': ids,
        },
      );
      return int.tryParse('$response') ?? 0;
    } on PostgrestException catch (error) {
      throw NotificationRepositoryFailure(_friendlyMutationMessage(error));
    }
  }

  Future<int> dismissAll() async {
    _requireSession();
    try {
      final response = await _client.rpc('dismiss_all_my_notifications');
      return int.tryParse('$response') ?? 0;
    } on PostgrestException catch (error) {
      throw NotificationRepositoryFailure(_friendlyMutationMessage(error));
    }
  }

  void _requireSession() {
    if (!SupabaseService.isInitialized || _client.auth.currentUser == null) {
      throw const NotificationRepositoryFailure(
        'سجّل الدخول لعرض مركز الإشعارات.',
      );
    }
  }

  String _friendlyMutationMessage(PostgrestException error) {
    final text = error.message.trim();
    if (text.contains('suspended') || text.contains('deleted')) {
      return 'الحساب غير نشط حاليًا.';
    }
    if (text.contains('Authentication')) {
      return 'سجّل الدخول لإدارة مركز الإشعارات.';
    }
    return 'تعذر حذف الإشعار من مركز الإشعارات. أعد المحاولة.';
  }

  String _friendlyMessage(PostgrestException error) {
    final text = error.message.trim();
    if (text.contains('suspended') || text.contains('deleted')) {
      return 'الحساب غير نشط حاليًا.';
    }
    if (text.contains('Authentication')) {
      return 'سجّل الدخول لعرض مركز الإشعارات.';
    }
    return 'تعذر تحميل الإشعارات. تحقق من الاتصال ثم أعد المحاولة.';
  }
}

class NotificationRepositoryFailure implements Exception {
  const NotificationRepositoryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
