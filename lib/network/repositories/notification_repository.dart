import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_constants.dart';
import '../../models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    String? body,
    String? actionId,
  }) async {
    try {
      await _supabase.from(AppConstants.collectionNotifications).insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'action_id': actionId,
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail
    }
  }

  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _supabase
        .from(AppConstants.collectionNotifications)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50)
        .map((data) => data.map((item) => NotificationModel.fromMap(item)).toList());
  }

  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from(AppConstants.collectionNotifications)
        .update({'read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _supabase
        .from(AppConstants.collectionNotifications)
        .update({'read': true})
        .eq('user_id', userId)
        .eq('read', false);
  }

  Future<int> getUnreadCount(String userId) async {
    final response = await _supabase
        .from(AppConstants.collectionNotifications)
        .select('id')
        .eq('user_id', userId)
        .eq('read', false);
    
    return response.length;
  }

  Stream<int> watchUnreadCount(String userId) {
    return _supabase
        .from(AppConstants.collectionNotifications)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) => data.where((item) => item['read'] == false).length);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _supabase
        .from(AppConstants.collectionNotifications)
        .delete()
        .eq('id', notificationId);
  }
}
