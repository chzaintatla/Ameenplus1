import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_constants.dart';

class AdminRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> isAdmin(String userId) async {
    final userData = await _supabase
        .from(AppConstants.collectionUsers)
        .select('is_admin')
        .eq('id', userId)
        .maybeSingle();

    return (userData?['is_admin'] ?? userData?['isAdmin']) == true;
  }

  Future<void> deleteUser(String userId) async {
    // Delete user data
    await _supabase
        .from(AppConstants.collectionUsers)
        .delete()
        .eq('id', userId);

    // Delete user's deeds
    await _supabase
        .from(AppConstants.collectionDeeds)
        .delete()
        .eq('user_id', userId);

    // Delete user's habits
    await _supabase
        .from(AppConstants.collectionHabits)
        .delete()
        .eq('user_id', userId);
  }

  Future<void> deleteDeed(String deedId) async {
    await _supabase
        .from(AppConstants.collectionDeeds)
        .delete()
        .eq('id', deedId);
  }

  Future<void> banUser(String userId) async {
    await _supabase
        .from(AppConstants.collectionUsers)
        .update({'is_banned': true})
        .eq('id', userId);
  }

  Future<void> unbanUser(String userId) async {
    await _supabase
        .from(AppConstants.collectionUsers)
        .update({'is_banned': false})
        .eq('id', userId);
  }

  Future<List<Map<String, dynamic>>> getAllUsers({int limit = 100}) async {
    return await _supabase
        .from(AppConstants.collectionUsers)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
  }

  Future<List<Map<String, dynamic>>> getReportedContent() async {
    return await _supabase
        .from('reports')
        .select()
        .order('created_at', ascending: false);
  }
}
