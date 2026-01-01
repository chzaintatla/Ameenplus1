import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_constants.dart';
import 'app_database.dart';
import '../models/user_model.dart';

class XPService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppDatabase _localDb = AppDatabase.instance;

  Future<void> awardXP({
    required String userId,
    required int xpAmount,
    required String actionType,
    String? description,
  }) async {
    try {
      final userRef = _firestore.collection(AppConstants.collectionUsers).doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        final data = userDoc.data()!;
        final currentXP = (data['xp'] ?? 0) as int;
        final newXP = currentXP + xpAmount;
        final newLevel = UserModel.calculateLevel(newXP);

        final badges = List<String>.from(data['badges'] ?? []);
        final newBadges = _checkBadgeUnlocks(newXP, newLevel, actionType, badges);

        transaction.update(userRef, {
          'xp': newXP,
          'level': newLevel,
          'badges': newBadges,
          'lastActive': FieldValue.serverTimestamp(),
        });

        if (data['isProfilePublic'] == true) {
          await _updateLeaderboard(userId, newXP, data['displayName'] ?? 'User', data['photoUrl'] ?? data['profilePicture']);
        }
      });

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

  Future<void> _updateLeaderboard(String userId, int xp, String displayName, String? photoUrl) async {
    try {
      await _firestore.collection('leaderboard_public').doc(userId).set({
        'userId': userId,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'points': xp,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      await _firestore.collection(AppConstants.collectionUsers).doc(userId).update({
        'points': xp,
      });
    } catch (e) {
    }
  }

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
    }
    return 0;
  }
}
