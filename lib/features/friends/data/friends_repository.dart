import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_constants.dart';
import '../models/friend_model.dart';
import '../../notifications/data/notification_repository.dart';

class FriendsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationRepository _notificationRepo = NotificationRepository();

  /// Send friend request
  Future<void> sendFriendRequest({
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String receiverId,
  }) async {
    // Check if request already exists
    final existingRequest = await _firestore
        .collection(AppConstants.collectionFriendRequests)
        .where('senderId', isEqualTo: senderId)
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception('Friend request already sent');
    }

    // Create friend request
    await _firestore.collection(AppConstants.collectionFriendRequests).add({
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'receiverId': receiverId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send notification
    await _notificationRepo.createNotification(
      userId: receiverId,
      type: 'friend_request',
      title: 'New Friend Request',
      body: '$senderName wants to be your friend',
      actionId: senderId,
    );
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(String requestId) async {
    final requestDoc = await _firestore
        .collection(AppConstants.collectionFriendRequests)
        .doc(requestId)
        .get();

    if (!requestDoc.exists) {
      throw Exception('Friend request not found');
    }

    final data = requestDoc.data()!;
    final senderId = data['senderId'] as String;
    final receiverId = data['receiverId'] as String;
    final senderName = data['senderName'] as String;

    // Update request status
    await requestDoc.reference.update({
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    // Add to friends list for both users
    await Future.wait([
      _firestore.collection(AppConstants.collectionUsers).doc(senderId).update({
        'friends': FieldValue.arrayUnion([receiverId]),
      }),
      _firestore.collection(AppConstants.collectionUsers).doc(receiverId).update({
        'friends': FieldValue.arrayUnion([senderId]),
      }),
    ]);

    // Send notification
    await _notificationRepo.createNotification(
      userId: senderId,
      type: 'friend_accepted',
      title: 'Friend Request Accepted',
      body: 'Your friend request has been accepted',
      actionId: receiverId,
    );
  }

  /// Reject friend request
  Future<void> rejectFriendRequest(String requestId) async {
    await _firestore
        .collection(AppConstants.collectionFriendRequests)
        .doc(requestId)
        .update({
      'status': 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get friend requests for user
  Stream<List<FriendRequestModel>> getFriendRequests(String userId) {
    return _firestore
        .collection(AppConstants.collectionFriendRequests)
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FriendRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get user's friends
  Stream<List<FriendModel>> getFriends(String userId) async* {
    final userDoc = await _firestore
        .collection(AppConstants.collectionUsers)
        .doc(userId)
        .get();

    if (!userDoc.exists) {
      yield [];
      return;
    }

    final friendsList = List<String>.from(userDoc.data()?['friends'] ?? []);
    
    if (friendsList.isEmpty) {
      yield [];
      return;
    }

    // Get friends data
    final friendsDocs = await Future.wait(
      friendsList.map((friendId) => 
        _firestore.collection(AppConstants.collectionUsers).doc(friendId).get()
      ),
    );

    yield friendsDocs
        .where((doc) => doc.exists)
        .map((doc) {
          final data = doc.data()!;
          return FriendModel(
            userId: doc.id,
            displayName: data['displayName'] ?? 'User',
            profilePicture: data['profilePicture'],
            xp: data['xp'] ?? 0,
            level: data['level'] ?? 1,
            badges: List<String>.from(data['badges'] ?? []),
            isOnline: data['isOnline'] ?? false,
            lastActive: data['lastActive'] != null
                ? (data['lastActive'] as Timestamp).toDate()
                : null,
            friendsSince: DateTime.now(), // Could be improved with actual friendsSince field
          );
        })
        .toList();
  }

  /// Remove friend
  Future<void> removeFriend(String userId, String friendId) async {
    await Future.wait([
      _firestore.collection(AppConstants.collectionUsers).doc(userId).update({
        'friends': FieldValue.arrayRemove([friendId]),
      }),
      _firestore.collection(AppConstants.collectionUsers).doc(friendId).update({
        'friends': FieldValue.arrayRemove([userId]),
      }),
    ]);
  }
}

