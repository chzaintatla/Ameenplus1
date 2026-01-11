import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_ready_provider.dart';
import '../network/repositories/leaderboard_repository.dart';
import '../models/leaderboard_user.dart';

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  final readyAsync = ref.watch(supabaseReadyProvider);
  
  return readyAsync.maybeWhen(
    data: (ready) => ready ? LeaderboardRepository() : LeaderboardRepository(),
    orElse: () => LeaderboardRepository(),
  );
});

final globalLeaderboardProvider = FutureProvider<List<LeaderboardUser>>((ref) async {
  final repository = ref.watch(leaderboardRepositoryProvider);
  return await repository.getGlobalLeaderboard(limit: 50);
});

final top5LeaderboardProvider = FutureProvider<List<dynamic>>((ref) async {
  final repository = ref.watch(leaderboardRepositoryProvider);
  return await repository.getGlobalLeaderboard(limit: 5);
});

final regionalLeaderboardProvider = FutureProvider.family<List<dynamic>, String>((ref, region) async {
  final repository = ref.watch(leaderboardRepositoryProvider);
  return await repository.getRegionalLeaderboard(region, limit: 50);
});

final userRankProvider = FutureProvider.family<int, String>((ref, userId) async {
  final repository = ref.watch(leaderboardRepositoryProvider);
  return await repository.getUserRank(userId);
});
