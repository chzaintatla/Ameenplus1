import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';

final supabaseReadyProvider = FutureProvider<bool>((ref) async {
  try {
    // Check if Supabase is already initialized
    if (Supabase.instance.client.auth.currentSession != null || 
        SupabaseConfig.isConfigured) {
      return true;
    }
    
    // If not initialized, try to initialize
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      debug: SupabaseConfig.isDebugMode,
    );
    return true;
  } catch (e) {
    print('Supabase initialization error: $e');
    return false;
  }
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
