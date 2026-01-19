import 'package:flutter/foundation.dart';

/// Supabase configuration for the Ameen+ app
/// 
/// Project URL: https://supabase.com/dashboard/project/drvzadcgkfranrcmaixs
class SupabaseConfig {
  // Your Supabase project URL
  static const String supabaseUrl = 'https://razquazlolqlnrdgregm.supabase.co';
  
  // Your Supabase anon public key
  static const String supabaseAnonKey = 'sb_publishable_XyRIwww2pfKcGR90OJYTMg_pqztBbdq';
  
  // Groq API key for AI features
  static const String groqApiKey = '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';
  
  // Google Client IDs for OAuth
  static const String googleIosClientId = '105816685190-751mhaubnde07nfirqs59ofm9gno18f5.apps.googleusercontent.com';
  static const String googleAndroidClientId = '105816685190-ls6a9k5qpnl3unibumc3opl73uje7m29.apps.googleusercontent.com';
  static const String googleWebClientId = '105816685190-iot99otikchhu77nqmi38ap07vs00i9m.apps.googleusercontent.com';

  // Optional: Deep link configuration for OAuth
  static const String deepLinkScheme = 'com.example.ameenplus';
  
  // Debug mode
  static bool get isDebugMode => kDebugMode;
  
  /// Validate that Supabase is configured
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && 
           supabaseAnonKey.isNotEmpty;
  }
}
