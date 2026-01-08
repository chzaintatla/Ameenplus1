import 'package:flutter/foundation.dart';

/// Supabase configuration for the Ameen+ app
/// 
/// Project URL: https://supabase.com/dashboard/project/drvzadcgkfranrcmaixs
class SupabaseConfig {
  // Your Supabase project URL
  static const String supabaseUrl = 'https://drvzadcgkfranrcmaixs.supabase.co';
  
  // Your Supabase anon public key
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRydnphZGNna2ZyYW5yY21haXhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY0MzM2NzMsImV4cCI6MjA1MjAwOTY3M30.sb_publishable_9fm5xzxTFQA5RUeGdj_X5w_KSBbE';
  
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
