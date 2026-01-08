import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/daily_deed.dart';

class DailyDeedsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getDailyDeeds() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final deeds = await _supabase
          .from('deeds')
          .select()
          .gte('created_at', startOfDay.toIso8601String())
          .order('created_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(deeds);
    } catch (e) {
      return [];
    }
  }

  Future<int> getUserDailyDeedCount(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final deeds = await _supabase
          .from('deeds')
          .select()
          .eq('user_id', userId)
          .gte('created_at', startOfDay.toIso8601String());

      return deeds.length;
    } catch (e) {
      return 0;
    }
  }

  Future<DailyDeed?> getTodaysDeed(UserProfile profile) async {
    // In a real app, this would use AI (like Groq) to generate a deed
    // or fetch from a curated database based on user interests.
    
    final interest = profile.interests.isNotEmpty 
        ? profile.interests.first 
        : 'Kindness';

    return DailyDeed(
      name: 'Act of $interest',
      description: 'Perform a small act related to $interest today to please Allah.',
      connection: 'This initiative aligns with your interest in $interest.',
      benefit: 'Increased mindfulness and spiritual reward.',
      interests: profile.interests,
    );
  }
}
