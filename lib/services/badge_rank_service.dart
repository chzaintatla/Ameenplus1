import 'package:supabase_flutter/supabase_flutter.dart';

class BadgeRankService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<String>> getUserBadges(String userId) async {
    try {
      final userData = await _supabase
          .from('users')
          .select('badges')
          .eq('id', userId)
          .maybeSingle();

      return List<String>.from(userData?['badges'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<int> getUserRank(String userId) async {
    try {
      final userData = await _supabase
          .from('users')
          .select('points')
          .eq('id', userId)
          .maybeSingle();

      if (userData == null) return 0;

      final userPoints = userData['points'] ?? 0;

      final higherRanked = await _supabase
          .from('users')
          .select()
          .gt('points', userPoints);

      return higherRanked.length + 1;
    } catch (e) {
      return 0;
    }
  }

  String getBadgeIcon(String badgeName) {
    switch (badgeName) {
      case 'streak_warrior':
        return '🔥';
      case 'community_builder':
        return '👥';
      case 'knowledge_seeker':
        return '📚';
      case 'generous_giver':
        return '💝';
      default:
        return '⭐';
    }
  }
}
