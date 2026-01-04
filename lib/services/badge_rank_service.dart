import 'package:cloud_firestore/cloud_firestore.dart';

class BadgeRankService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<String> availableBadges = [
    'Siddiq',      // Truthful - for honest content
    'Ameen',       // Trustworthy - for reliable posts
    'Mujahid',     // Striver - for consistent activity
    'Alim',        // Scholar - for educational content
    'Hafiz',       // Memorizer - for Quran-related content
    'Sadiq',       // Sincere - for genuine engagement
    'Mutawakkil',  // Trusting in Allah - for patience
    'Shakir',      // Grateful - for gratitude posts
    'Sabir',       // Patient - for perseverance
    'Karim',
  ];

  static const Map<String, int> rankThresholds = {
    'Beginner': 0,
    'Seeker': 100,
    'Learner': 500,
    'Practitioner': 1000,
    'Devoted': 2500,
    'Righteous': 5000,
    'Virtuous': 10000,
    'Exemplary': 25000,
    'Noble': 50000,
    'Elite': 100000,
  };

  String calculateRank(int points) {
    String currentRank = 'Beginner';
    for (final entry in rankThresholds.entries) {
      if (points >= entry.value) {
        currentRank = entry.key;
      } else {
        break;
      }
    }
    return currentRank;
  }

  Future<void> awardBadge(String userId, String badgeName) async {
    if (!availableBadges.contains(badgeName)) {
      throw Exception('Invalid badge name: $badgeName');
    }

    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('User not found');
    }

    final userData = userDoc.data()!;
    final currentBadges = List<String>.from(userData['badges'] ?? []);

    if (!currentBadges.contains(badgeName)) {
      currentBadges.add(badgeName);
      await _firestore.collection('users').doc(userId).update({
        'badges': currentBadges,
      });

      await _firestore.collection('badge_awards').add({
        'userId': userId,
        'badgeName': badgeName,
        'awardedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> checkAndAwardBadges(String userId, {
    required int points,
    required int postsCount,
    required int engagementScore,
    required bool hasQuranContent,
    required bool hasEducationalContent,
  }) async {
    final badgesToAward = <String>[];

    if (engagementScore > 100 && postsCount > 10) {
      badgesToAward.add('Siddiq');
    }

    if (postsCount > 50) {
      badgesToAward.add('Ameen');
    }

    if (points > 1000) {
      badgesToAward.add('Mujahid');
    }

    if (hasEducationalContent && postsCount > 20) {
      badgesToAward.add('Alim');
    }

    if (hasQuranContent && postsCount > 10) {
      badgesToAward.add('Hafiz');
    }

    for (final badge in badgesToAward) {
      await awardBadge(userId, badge);
    }

    final rank = calculateRank(points);
    await _firestore.collection('users').doc(userId).update({
      'rank': rank,
    });
  }

  Future<List<String>> getUserBadges(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return [];

    final userData = userDoc.data()!;
    return List<String>.from(userData['badges'] ?? []);
  }

  Future<String> getUserRank(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return 'Beginner';

    final userData = userDoc.data()!;
    final points = (userData['points'] as num?)?.toInt() ?? 0;
    return calculateRank(points);
  }
}

