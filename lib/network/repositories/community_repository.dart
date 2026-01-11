import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_constants.dart';
import '../../models/community_model.dart';

class CommunityRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> createCommunity(CommunityModel community) async {
    await _supabase
        .from(AppConstants.collectionCommunities)
        .insert(community.toMap());
  }

  Stream<List<CommunityModel>> getCommunities() {
    return _supabase
        .from(AppConstants.collectionCommunities)
        .stream(primaryKey: ['id'])
        .map((data) {
          final communities = data.map((item) => CommunityModel.fromMap(item)).toList();
          communities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return communities;
        });
  }

  Future<CommunityModel?> getCommunity(String communityId) async {
    final data = await _supabase
        .from(AppConstants.collectionCommunities)
        .select()
        .eq('id', communityId)
        .maybeSingle();
    
    if (data == null) return null;
    return CommunityModel.fromMap(data);
  }

  Future<bool> isMember(String communityId, String userId) async {
    final data = await _supabase
        .from(AppConstants.collectionCommunities)
        .select('members')
        .eq('id', communityId)
        .maybeSingle();
    
    if (data == null) return false;
    final members = List<String>.from(data['members'] ?? []);
    return members.contains(userId);
  }

  Stream<List<CommunityModel>> getUserCommunities(String userId) {
    return _supabase
        .from(AppConstants.collectionCommunities)
        .stream(primaryKey: ['id'])
        .map((data) {
          final communities = data
              .where((item) => (item['members'] as List?)?.contains(userId) ?? false)
              .map((item) => CommunityModel.fromMap(item))
              .toList();
          return communities;
        });
  }

  Future<void> joinCommunity(String communityId, String userId) async {
    final communityData = await _supabase
        .from(AppConstants.collectionCommunities)
        .select()
        .eq('id', communityId)
        .maybeSingle();

    if (communityData != null) {
      final members = List<String>.from(communityData['members'] ?? []);
      if (!members.contains(userId)) {
        members.add(userId);
        await _supabase
            .from(AppConstants.collectionCommunities)
            .update({
              'members': members,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', communityId);
      }
    }
  }

  Future<void> leaveCommunity(String communityId, String userId) async {
    final communityData = await _supabase
        .from(AppConstants.collectionCommunities)
        .select()
        .eq('id', communityId)
        .maybeSingle();

    if (communityData != null) {
      final members = List<String>.from(communityData['members'] ?? []);
      members.remove(userId);
      await _supabase
          .from(AppConstants.collectionCommunities)
          .update({
            'members': members,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', communityId);
    }
  }

  Future<void> deleteCommunity(String communityId, String userId) async {
    final communityData = await _supabase
        .from(AppConstants.collectionCommunities)
        .select()
        .eq('id', communityId)
        .maybeSingle();

    if (communityData == null || (communityData['created_by'] ?? communityData['createdBy']) != userId) {
      throw Exception('Unauthorized');
    }

    await _supabase
        .from(AppConstants.collectionCommunities)
        .delete()
        .eq('id', communityId);
  }
}
