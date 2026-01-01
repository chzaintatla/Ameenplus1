import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/app_constants.dart';
import '../../models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get notifications stream for current user
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection(AppConstants.collectionNotifications)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    }).handleError((error, stackTrace) {
      // Handle index building errors gracefully
      // The error will be caught by the StreamProvider
    });
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection(AppConstants.collectionNotifications)
        .doc(notificationId)
        .update({'read': true, 'readAt': FieldValue.serverTimestamp()});
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection(AppConstants.collectionNotifications)
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    for (var doc in notifications.docs) {
      batch.update(doc.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Get unread count
  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection(AppConstants.collectionNotifications)
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Create a notification
  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? actionId,
    Map<String, dynamic>? data,
  }) async {
    final notification = NotificationModel(
      id: '',
      userId: userId,
      type: type,
      title: title,
      body: body,
      actionId: actionId,
      data: data,
      read: false,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.collectionNotifications)
        .add(notification.toFirestore());
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection(AppConstants.collectionNotifications)
        .doc(notificationId)
        .delete();
  }
}

