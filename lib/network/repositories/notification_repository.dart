import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../../utils/app_constants.dart';
import '../../models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  
  static Future<void> initializeLocalNotifications() async {
    if (_initialized) return;
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    final initialized = await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap if needed in the future
        if (kDebugMode) {
          debugPrint('Notification tapped: ${response.payload}');
        }
      },
    );
    
    if (initialized != true) {
      if (kDebugMode) {
        debugPrint('Failed to initialize local notifications');
      }
      return;
    }
    
    // Request notification permissions on Android 13+
    final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
    
    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Notifications for community and chat messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    
    await androidImplementation?.createNotificationChannel(androidChannel);
    
    _initialized = true;
  }

  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    String? body,
    String? actionId,
    bool showPushNotification = true,
  }) async {
    try {
      // Save notification to database (for in-app notifications screen)
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
      if (kDebugMode) {
        debugPrint('Error creating notification: $e');
      }
    }
  }

  static void startNotificationListener(String userId) {
    Supabase.instance.client
        .from(AppConstants.collectionNotifications)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((data) {
          if (data.isNotEmpty) {
            // Check for unread notifications in the stream data
            for (var item in data) {
              if (item['read'] == false) {
                final createdAt = DateTime.parse(item['created_at']);
                // Only show if it was created in the last 10 seconds to avoid spamming old notifications
                if (DateTime.now().difference(createdAt).inSeconds < 10) {
                  _showLocalNotification(
                    item['title'] ?? 'New Notification',
                    item['body'] ?? '',
                    item['action_id'],
                    item['type'],
                  );
                  // We only show one local notification at a time typically
                  break; 
                }
              }
            }
          }
        });
  }

  static Future<void> _showLocalNotification(String title, String body, String? actionId, String type) async {
    if (!_initialized) await initializeLocalNotifications();
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 2147483647,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_messages',
          'Chat Messages',
          channelDescription: 'Notifications for community and chat messages',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: actionId != null ? 'type:$type|actionId:$actionId' : null,
    );
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
