import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'notification_repository.dart';

class FollowRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationRepository _notificationRepo = NotificationRepository();

  Future<void> followUser(String followerId, String followingId) async {
    // Insert follow relationship
    await _supabase.from('follows').insert({
      'id': const Uuid().v4(), // Generate unique ID
      'follower_id': followerId,
      'following_id': followingId,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Update follower count for the user being followed
    final followingUserData = await _supabase
        .from('users')
        .select('followers_count, display_name')
        .eq('id', followingId)
        .maybeSingle();
    
    if (followingUserData != null) {
      final currentFollowersCount = (followingUserData['followers_count'] as num?)?.toInt() ?? 0;
      await _supabase
          .from('users')
          .update({'followers_count': currentFollowersCount + 1})
          .eq('id', followingId);

      // Notify the user being followed
      try {
        final followerData = await _supabase
            .from('users')
            .select('display_name')
            .eq('id', followerId)
            .maybeSingle();
        
        final followerName = followerData?['display_name'] ?? 'Someone';
        
        await _notificationRepo.createNotification(
          userId: followingId,
          type: 'friend_request', // Using existing type mapping in UI
          title: 'New Follower',
          body: '$followerName is now following you',
          actionId: followerId,
        );
      } catch (e) {
        // Silently fail notification
      }
    }

    // Update following count for the follower
    final followerUserData = await _supabase
        .from('users')
        .select('following_count')
        .eq('id', followerId)
        .maybeSingle();
    
    if (followerUserData != null) {
      final currentFollowingCount = (followerUserData['following_count'] as num?)?.toInt() ?? 0;
      await _supabase
          .from('users')
          .update({'following_count': currentFollowingCount + 1})
          .eq('id', followerId);
    }
  }

  Future<void> unfollowUser(String followerId, String followingId) async {
    // Delete follow relationship
    await _supabase
        .from('follows')
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', followingId);

    // Update follower count for the user being unfollowed
    final followingUserData = await _supabase
        .from('users')
        .select('followers_count')
        .eq('id', followingId)
        .maybeSingle();
    
    if (followingUserData != null) {
      final currentFollowersCount = (followingUserData['followers_count'] as num?)?.toInt() ?? 0;
      await _supabase
          .from('users')
          .update({'followers_count': (currentFollowersCount - 1).clamp(0, 999999)})
          .eq('id', followingId);
    }

    // Update following count for the unfollower
    final followerUserData = await _supabase
        .from('users')
        .select('following_count')
        .eq('id', followerId)
        .maybeSingle();
    
    if (followerUserData != null) {
      final currentFollowingCount = (followerUserData['following_count'] as num?)?.toInt() ?? 0;
      await _supabase
          .from('users')
          .update({'following_count': (currentFollowingCount - 1).clamp(0, 999999)})
          .eq('id', followerId);
    }
  }

  Stream<bool> watchIsFollowing(String followerId, String followingId) {
    return _supabase
        .from('follows')
        .stream(primaryKey: ['id'])
        .eq('following_id', followingId)
        .map((data) => data.any((item) => item['follower_id'] == followerId));
  }

  Future<bool> isFollowing(String followerId, String followingId) async {
    final data = await _supabase
        .from('follows')
        .select()
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();

    return data != null;
  }

  Stream<List<Map<String, dynamic>>> watchFollowers(String userId) {
    return _supabase
        .from('follows')
        .stream(primaryKey: ['id'])
        .eq('following_id', userId)
        .asyncMap((data) async {
          if (data.isEmpty) return [];
          
          final followerIds = data.map((item) => item['follower_id'] as String).toList();
          final usersData = await _supabase
              .from('users')
              .select('id, display_name, photo_url, email, is_email_public')
              .filter('id', 'in', followerIds);
          
          return List<Map<String, dynamic>>.from(usersData);
        });
  }

  Stream<List<Map<String, dynamic>>> watchFollowing(String userId) {
    return _supabase
        .from('follows')
        .stream(primaryKey: ['id'])
        .eq('follower_id', userId)
        .asyncMap((data) async {
          if (data.isEmpty) return [];
          
          final followingIds = data.map((item) => item['following_id'] as String).toList();
          final usersData = await _supabase
              .from('users')
              .select('id, display_name, photo_url, email, is_email_public')
              .filter('id', 'in', followingIds);
          
          return List<Map<String, dynamic>>.from(usersData);
        });
  }

  Future<int> getFollowerCount(String userId) async {
    final response = await _supabase
        .from('follows')
        .select('id')
        .eq('following_id', userId);
    
    return response.length;
  }

  Future<int> getFollowingCount(String userId) async {
    final response = await _supabase
        .from('follows')
        .select('id')
        .eq('follower_id', userId);
    
    return response.length;
  }

  // Helper for backward compatibility if needed by some providers
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    return await _supabase
        .from('users')
        .select('id, display_name, photo_url, email, is_email_public')
        .eq('id', userId)
        .maybeSingle();
  }
}
