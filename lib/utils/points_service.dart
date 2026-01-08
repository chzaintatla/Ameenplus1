import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_constants.dart';

class PointsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const int maxPointsPerDay = 1000;
  static const int tasbihPointsPer100 = 10;
  static const double farzNamazPoints = 1.0;
  static const double nafalNamazPoints = 0.65;

  Future<void> addHabitPoints({
    required String userId,
    required double points,
  }) async {
    try {
      final userData = await _supabase
          .from(AppConstants.collectionUsers)
          .select('points')
          .eq('id', userId)
          .maybeSingle();

      if (userData != null) {
        final currentPoints = (userData['points'] ?? 0) as int;
        final newPoints = currentPoints + points.toInt();

        await _supabase
            .from(AppConstants.collectionUsers)
            .update({'points': newPoints})
            .eq('id', userId);
        
        await _recordPointTransaction(userId, points, 'habit');
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> addDeedPoints({
    required String userId,
    required double points,
  }) async {
    await addHabitPoints(userId: userId, points: points);
  }

  Future<void> addNamazPoints({
    required String userId,
    required int farzCount,
    required int nafalCount,
  }) async {
    final points = (farzCount * farzNamazPoints) + (nafalCount * nafalNamazPoints);
    await addHabitPoints(userId: userId, points: points);
    
    if (farzCount > 0) {
      await _recordPointTransaction(userId, farzCount * farzNamazPoints, 'namaz_farz');
    }
    if (nafalCount > 0) {
      await _recordPointTransaction(userId, nafalCount * nafalNamazPoints, 'namaz_nafal');
    }
  }

  Future<void> addTasbihPoints(String userId, int count) async {
    final points = (count / 100).floor() * tasbihPointsPer100;
    if (points > 0) {
      await addHabitPoints(userId: userId, points: points.toDouble());
      await _recordPointTransaction(userId, points.toDouble(), 'tasbih');
    }
  }

  Future<int> getUserPoints(String userId) async {
    try {
      final userData = await _supabase
          .from(AppConstants.collectionUsers)
          .select('points')
          .eq('id', userId)
          .maybeSingle();

      return (userData?['points'] ?? 0) as int;
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, dynamic>> getDailyStats(String userId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final startOfDay = '${today}T00:00:00.000000';
      
      final data = await _supabase
          .from('point_transactions')
          .select('amount, type')
          .eq('user_id', userId)
          .gte('created_at', startOfDay);
      
      double totalPointsToday = 0;
      int farzCount = 0;
      int nafalCount = 0;
      
      for (final item in data) {
        final amount = (item['amount'] as num).toDouble();
        final type = item['type'] as String;
        
        totalPointsToday += amount;
        if (type == 'namaz_farz') farzCount++;
        if (type == 'namaz_nafal') nafalCount++;
      }
      
      return {
        'totalPoints': totalPointsToday,
        'farzCount': farzCount,
        'nafalCount': nafalCount,
        'maxPoints': maxPointsPerDay.toDouble(),
        'percentage': (totalPointsToday / maxPointsPerDay).clamp(0.0, 1.0),
      };
    } catch (e) {
      return {
        'totalPoints': 0.0,
        'farzCount': 0,
        'nafalCount': 0,
        'maxPoints': maxPointsPerDay.toDouble(),
        'percentage': 0.0,
      };
    }
  }

  Future<void> _recordPointTransaction(String userId, double amount, String type) async {
    try {
      await _supabase.from('point_transactions').insert({
        'user_id': userId,
        'amount': amount,
        'type': type,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Table might not exist
    }
  }
}
