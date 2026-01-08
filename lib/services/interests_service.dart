import 'package:supabase_flutter/supabase_flutter.dart';

class InterestsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<String>> getUserInterests(String userId) async {
    try {
      final userData = await _supabase
          .from('users')
          .select('interests')
          .eq('id', userId)
          .maybeSingle();

      return List<String>.from(userData?['interests'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<void> updateUserInterests(String userId, List<String> interests) async {
    try {
      await _supabase
          .from('users')
          .update({'interests': interests})
          .eq('id', userId);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> incrementInterestCount(String interest) async {
    try {
      // Try to update existing record
      final existing = await _supabase
          .from('interest_stats')
          .select()
          .eq('name', interest)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('interest_stats')
            .update({'count': (existing['count'] as int) + 1})
            .eq('name', interest);
      } else {
        await _supabase.from('interest_stats').insert({
          'name': interest,
          'count': 1,
        });
      }
    } catch (e) {
      // Table might not exist yet, ignore
    }
  }

  Future<List<String>> getTrendingInterests({int limit = 10}) async {
    try {
      final data = await _supabase
          .from('interest_stats')
          .select('name')
          .order('count', ascending: false)
          .limit(limit);
      
      return data.map((item) => item['name'] as String).toList();
    } catch (e) {
      return getAvailableInterests().take(5).toList();
    }
  }

  List<String> getAvailableInterests() {
    return [
      'Quran',
      'Hadith',
      'Prayer',
      'Fasting',
      'Charity',
      'Islamic History',
      'Arabic Language',
      'Tafsir',
      'Fiqh',
      'Seerah',
    ];
  }
}
