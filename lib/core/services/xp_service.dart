import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../local/app_database.dart';
import '../../features/auth/models/user_model.dart';

/// Service for managing XP and score calculations
class XPService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppDatabase _localDb = AppDatabase.instance;

  /// Award XP to user for an action
  Future<void> awardXP({
    required String userId,
    required int xpAmount,
    required String actionType, // 'deed_post', 'habit_complete', 'comment', 'like', etc.
    String? description,
  }) async {
    try {
      // Update in Firestore
      final userRef = _firestore.collection(AppConstants.collectionUsers).doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        final data = userDoc.data()!;
        final currentXP = (data['xp'] ?? 0) as int;
        final newXP = currentXP + xpAmount;
        final newLevel = UserModel.calculateLevel(newXP);

        // Check for badge unlocks
        final badges = List<String>.from(data['badges'] ?? []);
        final newBadges = _checkBadgeUnlocks(newXP, newLevel, actionType, badges);

        transaction.update(userRef, {
          'xp': newXP,
          'level': newLevel,
          'badges': newBadges,
          'lastActive': FieldValue.serverTimestamp(),
        });

        // Update leaderboard if user is public
        if (data['isProfilePublic'] == true) {
          await _updateLeaderboard(userId, newXP, data['displayName'] ?? 'User', data['profilePicture']);
        }
      });

      // Update local cache
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        await _localDb.updateUserXP(
          userId,
          data['xp'] ?? 0,
          data['level'] ?? 1,
          (data['badges'] as List).join(','),
        );
      }
    } catch (e) {
      // If Firebase fails, still update locally
      final localXP = await _localDb.getUserXP(userId);
      final currentXP = localXP?['xpPoints'] ?? 0;
      final newXP = currentXP + xpAmount;
      final newLevel = UserModel.calculateLevel(newXP);

      await _localDb.updateUserXP(userId, newXP, newLevel, localXP?['badges'] ?? '');
    }
  }

  /// Award XP for posting a deed
  Future<void> awardXPForDeed(String userId) async {
    await awardXP(
      userId: userId,
      xpAmount: AppConstants.xpPerDeedPost,
      actionType: 'deed_post',
      description: 'Posted a deed',
    );
  }

  /// Award XP for completing a habit
  Future<void> awardXPForHabit(String userId, {int streakDays = 0}) async {
    int xpAmount = AppConstants.xpPerHabitComplete;
    
    // Bonus XP for streaks
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

  /// Award XP for commenting
  Future<void> awardXPForComment(String userId) async {
    await awardXP(
      userId: userId,
      xpAmount: AppConstants.xpPerComment,
      actionType: 'comment',
      description: 'Commented on a deed',
    );
  }

  /// Award XP for liking (only once per deed)
  Future<void> awardXPForLike(String userId) async {
    await awardXP(
      userId: userId,
      xpAmount: AppConstants.xpPerLike,
      actionType: 'like',
      description: 'Liked a deed',
    );
  }

  /// Award daily login bonus
  Future<void> awardDailyLoginBonus(String userId) async {
    await awardXP(
      userId: userId,
      xpAmount: AppConstants.xpDailyLoginBonus,
      actionType: 'daily_login',
      description: 'Daily login bonus',
    );
  }

  /// Check for badge unlocks
  List<String> _checkBadgeUnlocks(int xp, int level, String actionType, List<String> currentBadges) {
    final badges = List<String>.from(currentBadges);

    // Level-based badges
    if (level >= 5 && !badges.contains(AppConstants.badgeStreakWarrior)) {
      badges.add(AppConstants.badgeStreakWarrior);
    }
    if (level >= 10 && !badges.contains(AppConstants.badgeCommunityBuilder)) {
      badges.add(AppConstants.badgeCommunityBuilder);
    }

    // Action-based badges (check in repository when action happens)
    // These are checked when specific actions occur

    return badges;
  }

  /// Update leaderboard
  Future<void> _updateLeaderboard(String userId, int xp, String displayName, String? photoUrl) async {
    try {
      await _firestore.collection('leaderboard_public').doc(userId).set({
        'userId': userId,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'points': xp, // Use XP as points
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Leaderboard update failed, but don't fail the whole operation
    }
  }

  /// Get user's current XP and level
  Future<Map<String, dynamic>?> getUserStats(String userId) async {
    try {
      final userDoc = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        return {
          'xp': data['xp'] ?? 0,
          'level': data['level'] ?? 1,
          'badges': data['badges'] ?? [],
        };
      }
    } catch (e) {
      // Try local cache
      return await _localDb.getUserXP(userId);
    }
    return null;
  }

  /// Calculate total score from various activities
  Future<int> calculateTotalScore(String userId) async {
    try {
      final stats = await getUserStats(userId);
      if (stats != null) {
        return stats['xp'] ?? 0;
      }
    } catch (e) {
      // Return 0 if calculation fails
    }
    return 0;
  }
}

