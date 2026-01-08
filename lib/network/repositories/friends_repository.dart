import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_constants.dart';
import '../../models/friend_model.dart';
import 'notification_repository.dart';

class FriendsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationRepository _notificationRepo = NotificationRepository();

  Future<void> sendFriendRequest(String fromUserId, String toUserId) async {
    await _supabase.from(AppConstants.collectionFriends).insert({
      'user_id': fromUserId,
      'friend_id': toUserId,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await _notificationRepo.createNotification(
      userId: toUserId,
      type: 'friend_request',
      title: 'New Friend Request',
      body: 'You have a new friend request',
      actionId: fromUserId,
    );
  }

  Future<void> acceptFriendRequest(String userId, String friendId) async {
    await _supabase
        .from(AppConstants.collectionFriends)
        .update({
          'status': 'accepted',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', friendId)
        .eq('friend_id', userId);

    // Create reciprocal friendship
    await _supabase.from(AppConstants.collectionFriends).insert({
      'user_id': userId,
      'friend_id': friendId,
      'status': 'accepted',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await _notificationRepo.createNotification(
      userId: friendId,
      type: 'friend_accept',
      title: 'Friend Request Accepted',
      body: 'Your friend request was accepted',
      actionId: userId,
    );
  }

  Future<void> rejectFriendRequest(String userId, String friendId) async {
    await _supabase
        .from(AppConstants.collectionFriends)
        .delete()
        .eq('user_id', friendId)
        .eq('friend_id', userId);
  }

  Future<void> removeFriend(String userId, String friendId) async {
    await _supabase
        .from(AppConstants.collectionFriends)
        .delete()
        .or('user_id.eq.$userId,friend_id.eq.$userId')
        .or('user_id.eq.$friendId,friend_id.eq.$friendId');
  }

  Stream<List<FriendModel>> getFriends(String userId) {
    return _supabase
        .from(AppConstants.collectionFriends)
        .stream(primaryKey: ['id'])
        .map((data) {
          return data
              .where((item) => item['user_id'] == userId && item['status'] == 'accepted')
              .map((item) => FriendModel.fromMap(item))
              .toList();
        });
  }

  Stream<List<FriendModel>> getPendingRequests(String userId) {
    return _supabase
        .from(AppConstants.collectionFriends)
        .stream(primaryKey: ['id'])
        .map((data) {
          return data
              .where((item) => item['friend_id'] == userId && item['status'] == 'pending')
              .map((item) => FriendModel.fromMap(item))
              .toList();
        });
  }

  Future<bool> areFriends(String userId1, String userId2) async {
    final data = await _supabase
        .from(AppConstants.collectionFriends)
        .select()
        .eq('user_id', userId1)
        .eq('friend_id', userId2)
        .eq('status', 'accepted')
        .maybeSingle();

    return data != null;
  }
}
