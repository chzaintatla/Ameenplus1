import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_constants.dart';
import '../models/user_model.dart';

class PointsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const double farzNamazPoints = 1.0;
  static const double nafalNamazPoints = 0.65;
  static const double maxPointsPerActivity = 5.0;
  static const double maxPointsPerDay = 10.0;
  static const double tasbihPointsPer100 = 2.0;

  Future<double> calculateNamazPoints({
    required int farzCount,
    required int nafalCount,
  }) async {
    double points = 0.0;
    points += (farzCount * farzNamazPoints).clamp(0.0, maxPointsPerActivity);
    points += (nafalCount * nafalNamazPoints).clamp(0.0, maxPointsPerActivity);
    return points.clamp(0.0, maxPointsPerDay);
  }

  Future<void> addNamazPoints({
    required String userId,
    required int farzCount,
    required int nafalCount,
  }) async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final points = await calculateNamazPoints(farzCount: farzCount, nafalCount: nafalCount);

    await _firestore.collection('daily_points').doc('$userId-$dateKey').set({
      'userId': userId,
      'date': dateKey,
      'namazPoints': points,
      'farzCount': farzCount,
      'nafalCount': nafalCount,
      'totalPoints': FieldValue.increment(points),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _checkAndUpdateStreak(userId, dateKey);
  }

  Future<void> addTasbihPoints({
    required String userId,
    required int count,
  }) async {
    final points = (count / 100).floor() * tasbihPointsPer100;
    if (points <= 0) return;

    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    await _firestore.collection('daily_points').doc('$userId-$dateKey').set({
      'userId': userId,
      'date': dateKey,
      'tasbihPoints': FieldValue.increment(points),
      'tasbihCount': FieldValue.increment(count),
      'totalPoints': FieldValue.increment(points),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _checkAndUpdateStreak(userId, dateKey);
  }

  Future<void> _checkAndUpdateStreak(String userId, String dateKey) async {
    final doc = await _firestore.collection('daily_points').doc('$userId-$dateKey').get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final totalPoints = (data['totalPoints'] ?? 0.0) as double;

    if (totalPoints >= 10.0) {
      await _updateStreak(userId, dateKey);
    } else {
      await _breakStreak(userId);
    }
  }

  Future<void> _breakStreak(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'streakDays': 0,
      'lastStreakDate': null,
    });
  }

  Future<void> _updateStreak(String userId, String dateKey) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    final userData = userDoc.data()!;
    final lastStreakDate = userData['lastStreakDate'] as String?;
    final currentStreak = userData['streakDays'] ?? 0;

    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    int newStreak = currentStreak;
    if (lastStreakDate == yesterdayKey || lastStreakDate == dateKey) {
      newStreak = currentStreak + 1;
    } else if (lastStreakDate != dateKey) {
      newStreak = 1;
    }

    await _firestore.collection('users').doc(userId).update({
      'streakDays': newStreak,
      'lastStreakDate': dateKey,
    });
  }

  Future<double> getTodayPoints(String userId) async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final doc = await _firestore.collection('daily_points').doc('$userId-$dateKey').get();
    if (!doc.exists) return 0.0;

    final data = doc.data()!;
    return (data['totalPoints'] ?? 0.0) as double;
  }

  Future<Map<String, dynamic>> getDailyStats(String userId) async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final doc = await _firestore.collection('daily_points').doc('$userId-$dateKey').get();
    if (!doc.exists) {
      return {
        'totalPoints': 0.0,
        'farzCount': 0,
        'nafalCount': 0,
        'tasbihCount': 0,
        'tasbihPoints': 0.0,
      };
    }

    final data = doc.data()!;
    return {
      'totalPoints': (data['totalPoints'] ?? 0.0) as double,
      'farzCount': data['farzCount'] ?? 0,
      'nafalCount': data['nafalCount'] ?? 0,
      'tasbihCount': data['tasbihCount'] ?? 0,
      'tasbihPoints': (data['tasbihPoints'] ?? 0.0) as double,
    };
  }

  Future<void> addHabitPoints({
    required String userId,
    required double points,
  }) async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    await _firestore.collection('daily_points').doc('$userId-$dateKey').set({
      'userId': userId,
      'date': dateKey,
      'habitPoints': FieldValue.increment(points),
      'totalPoints': FieldValue.increment(points),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _checkAndUpdateStreak(userId, dateKey);
  }
}

