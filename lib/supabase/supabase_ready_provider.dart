import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';

/// Provider to check if Supabase is ready for database and storage operations
/// Note: Supabase is used for database (posts) and storage (files), not authentication
final supabaseReadyProvider = FutureProvider<bool>((ref) async {
  try {
    // Check if Supabase is already initialized
    if (SupabaseConfig.isConfigured) {
      // Try to access storage to verify it's working
      try {
        await Supabase.instance.client.storage.from('avatars').list();
        return true;
      } catch (e) {
        // If not initialized, try to initialize
        await Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          anonKey: SupabaseConfig.supabaseAnonKey,
          debug: SupabaseConfig.isDebugMode,
        );
        return true;
      }
    }
    
    // If not initialized, try to initialize
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      debug: SupabaseConfig.isDebugMode,
    );
    return true;
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
    return false;
  }
});

// Helper to get Supabase client (for storage only)
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
