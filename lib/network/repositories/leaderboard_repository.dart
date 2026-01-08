import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_constants.dart';
import '../../models/leaderboard_user.dart';

class LeaderboardRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<LeaderboardUser>> getGlobalLeaderboard({int limit = 50}) async {
    final data = await _supabase
        .from(AppConstants.collectionUsers)
        .select()
        .order('points', ascending: false)
        .limit(limit);

    return data.map((item) => LeaderboardUser.fromMap(item)).toList();
  }

  Future<List<LeaderboardUser>> getRegionalLeaderboard(String region, {int limit = 50}) async {
    final data = await _supabase
        .from(AppConstants.collectionUsers)
        .select()
        .eq('region', region)
        .order('points', ascending: false)
        .limit(limit);

    return data.map((item) => LeaderboardUser.fromMap(item)).toList();
  }

  Future<int> getUserRank(String userId) async {
    final userData = await _supabase
        .from(AppConstants.collectionUsers)
        .select('points')
        .eq('id', userId)
        .maybeSingle();

    if (userData == null) return 0;

    final userPoints = userData['points'] ?? 0;

    final higherRanked = await _supabase
        .from(AppConstants.collectionUsers)
        .select()
        .gt('points', userPoints);

    return higherRanked.length + 1;
  }
}
