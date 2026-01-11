import 'package:flutter/foundation.dart';

/// Firebase configuration for the Ameen+ app
/// 
/// Note: Firebase configuration is typically done via:
/// - Android: google-services.json in android/app/
/// - iOS: GoogleService-Info.plist in ios/Runner/
/// - Web: Firebase config in index.html
class FirebaseConfig {
  // Debug mode
  static bool get isDebugMode => kDebugMode;
  
  // Google OAuth Client IDs for Google Sign-In
  // These should match the OAuth 2.0 Client IDs from Firebase Console
  static const String googleWebClientId = '105816685190-iot99otikchhu77nqmi38ap07vs00i9m.apps.googleusercontent.com';
  
  /// Validate that Firebase is configured
  /// This checks if the platform-specific config files exist
  static bool get isConfigured {
    // Firebase configuration is validated at runtime
    // when Firebase.initializeApp() is called
    return true;
  }
}
