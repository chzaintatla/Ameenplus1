import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_constants.dart';
import 'app_database.dart';
import '../models/user_model.dart';

class XPService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AppDatabase _localDb = AppDatabase.instance;

  Future<void> awardXP({
    required String userId,
    required int xpAmount,
    required String actionType,
    String? description,
  }) async {
    try {
      // Get current user data
      final userData = await _supabase
          .from(AppConstants.collectionUsers)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (userData == null) return;

      final currentXP = (userData['xp'] ?? 0) as int;
      final newXP = currentXP + xpAmount;
      final newLevel = UserModel.calculateLevel(newXP);

      final badges = List<String>.from(userData['badges'] ?? []);
      final newBadges = _checkBadgeUnlocks(newXP, newLevel, actionType, badges);

      // Update user XP and level
      await _supabase
          .from(AppConstants.collectionUsers)
          .update({
            'xp': newXP,
            'level': newLevel,
            'badges': newBadges,
            'last_active': DateTime.now().toIso8601String(),
            'points': newXP,
          })
          .eq('id', userId);

      // Update local database
      await _localDb.updateUserXP(
        userId,
        newXP,
        newLevel,
        newBadges.join(','),
      );
    } catch (e) {
      // Fallback to local database
      final localXP = await _localDb.getUserXP(userId);
      final currentXP = localXP?['xpPoints'] ?? 0;
      final newXP = currentXP + xpAmount;
      final newLevel = UserModel.calculateLevel(newXP);

      await _localDb.updateUserXP(userId, newXP, newLevel, localXP?['badges'] ?? '');
    }
  }

  Future<void> awardXPForDeed(String userId) async {
    await awardXP(
      userId: userId,
      xpAmount: AppConstants.xpPerDeedPost,
      actionType: 'deed_post',
      description: 'Posted a deed',
    );
  }

  Future<void> awardXPForHabit(String userId, {int streakDays = 0}) async {
    int xpAmount = AppConstants.xpPerHabitComplete;

    if (streakDays > 0) {
      xpAmount += streakDays * AppConstants.xpPerStreakDay;
    }

    await awardXP(
      userId: userId,
      xpAmount: xpAmount,
      actionType: 'habit_complete',
      description: 'Completed a habit',
    );
  }

  Future<void> awardXPForComment(String userId) async {
    await awardXP(
      userId: userId,
      xpAmount: AppConstants.xpPerComment,
      actionType: 'comment',
      description: 'Commented on a deed',
    );
  }

  Future<void> awardXPForLike(String userId) async {
    await awardXP(
      userId: userId,
      xpAmount: AppConstants.xpPerLike,
      actionType: 'like',
      description: 'Liked a deed',
    );
  }

  Future<void> awardXPForShare(String userId) async {
    await awardXP(
      userId: userId,
      xpAmount: AppConstants.xpPerShare,
      actionType: 'share',
      description: 'Shared a deed',
    );
  }

  Future<void> awardXPForFavorite(String userId) async {
    await awardXP(
      userId: userId,
      xpAmount: AppConstants.xpPerFavorite,
      actionType: 'favorite',
      description: 'Favorited a deed',
    );
  }

  Future<void> awardDailyLoginBonus(String userId) async {
    await awardXP(
      userId: userId,
      xpAmount: AppConstants.xpDailyLoginBonus,
      actionType: 'daily_login',
      description: 'Daily login bonus',
    );
  }

  List<String> _checkBadgeUnlocks(int xp, int level, String actionType, List<String> currentBadges) {
    final badges = List<String>.from(currentBadges);

    if (level >= 5 && !badges.contains(AppConstants.badgeStreakWarrior)) {
      badges.add(AppConstants.badgeStreakWarrior);
    }
    if (level >= 10 && !badges.contains(AppConstants.badgeCommunityBuilder)) {
      badges.add(AppConstants.badgeCommunityBuilder);
    }

    return badges;
  }

  Future<Map<String, dynamic>?> getUserStats(String userId) async {
    try {
      final userData = await _supabase
          .from(AppConstants.collectionUsers)
          .select('xp, level, badges')
          .eq('id', userId)
          .maybeSingle();

      if (userData != null) {
        return {
          'xp': userData['xp'] ?? 0,
          'level': userData['level'] ?? 1,
          'badges': userData['badges'] ?? [],
        };
      }
    } catch (e) {
      return await _localDb.getUserXP(userId);
    }
    return null;
  }

  Future<int> calculateTotalScore(String userId) async {
    try {
      final stats = await getUserStats(userId);
      if (stats != null) {
        return stats['xp'] ?? 0;
      }
    } catch (e) {
      // Ignore
    }
    return 0;
  }
}
