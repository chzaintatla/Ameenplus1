import 'package:supabase_flutter/supabase_flutter.dart';

class FollowRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> followUser(String followerId, String followingId) async {
    await _supabase.from('follows').insert({
      'follower_id': followerId,
      'following_id': followingId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> unfollowUser(String followerId, String followingId) async {
    await _supabase
        .from('follows')
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', followingId);
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
