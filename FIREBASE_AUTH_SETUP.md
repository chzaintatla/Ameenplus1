# Firebase Authentication Setup Guide

## Overview
This app uses **Firebase Authentication** for user authentication with **Email/Password** and **Google Sign-In** only.

## Firebase Console Configuration

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing one
3. Enable the following authentication methods:

### 2. Enable Authentication Methods

#### Email/Password Authentication
1. Go to **Authentication** → **Sign-in method**
2. Click on **Email/Password**
3. Enable **Email/Password** (first toggle)
4. Optionally enable **Email link (passwordless sign-in)** if needed
5. Click **Save**

#### Google Sign-In
1. Go to **Authentication** → **Sign-in method**
2. Click on **Google**
3. Enable **Google** sign-in
4. Enter your **Support email** (project support email)
5. Click **Save**

### 3. Configure OAuth Consent Screen (for Google Sign-In)
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Go to **APIs & Services** → **OAuth consent screen**
4. Configure:
   - User Type: External (or Internal if using Google Workspace)
   - App name: Ameen+
   - User support email: Your email
   - Developer contact: Your email
5. Add scopes:
   - `email`
   - `profile`
   - `openid`
6. Add test users if in testing mode
7. Save and continue

### 4. Get OAuth 2.0 Client IDs
1. Go to **APIs & Services** → **Credentials**
2. Find your **OAuth 2.0 Client IDs**:
   - **Web client** (for web platform)
   - **Android client** (for Android - auto-created with google-services.json)
   - **iOS client** (for iOS - auto-created with GoogleService-Info.plist)
3. Copy the **Client ID** for web platform
4. Update `lib/supabase_config.dart` with the web client ID:
   ```dart
   static const String googleWebClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
   ```

## Platform-Specific Setup

### Android Setup
1. Download `google-services.json` from Firebase Console:
   - Go to **Project Settings** → **Your apps** → **Android app**
   - Download `google-services.json`
2. Place `google-services.json` in `android/app/`
3. The Google Services plugin is already configured in:
   - `android/app/build.gradle.kts`
   - `android/build.gradle.kts`
4. **No additional configuration needed** - Google Sign-In works automatically via `google-services.json`

### iOS Setup
1. Download `GoogleService-Info.plist` from Firebase Console:
   - Go to **Project Settings** → **Your apps** → **iOS app**
   - Download `GoogleService-Info.plist`
2. Place `GoogleService-Info.plist` in `ios/Runner/`
3. Open `ios/Runner.xcworkspace` in Xcode
4. Drag `GoogleService-Info.plist` into the Runner project
5. **No additional configuration needed** - Google Sign-In works automatically via `GoogleService-Info.plist`

### Web Setup
1. The web client ID is configured in `lib/supabase_config.dart`
2. Make sure your Firebase project has a **Web app** registered
3. The OAuth redirect URIs are automatically configured by Firebase

## Code Configuration

### Authentication Repository
The `AuthRepository` class handles:
- **Email/Password** sign up and sign in
- **Google Sign-In** via Firebase
- User document creation in Supabase (for profile data)

### Key Files
- `lib/network/repositories/auth_repository.dart` - Authentication logic
- `lib/presentation/screens/auth_screen.dart` - Authentication UI
- `lib/supabase_config.dart` - Google OAuth Client IDs

## Testing

### Test Email/Password Authentication
1. Run the app
2. Tap "Sign Up" or "Sign In"
3. Enter email and password
4. Verify user is created in Firebase Console → Authentication
5. Verify user document is created in Supabase → users table

### Test Google Sign-In
1. Run the app
2. Tap "Continue with Google"
3. Select Google account
4. Verify user is created in Firebase Console → Authentication
5. Verify user document is created in Supabase → users table

## Troubleshooting

### Google Sign-In Issues

#### Android
- **Error**: "sign_in_failed"
  - **Solution**: Ensure `google-services.json` is in `android/app/`
  - Verify SHA-1 fingerprint is added in Firebase Console
  - Get SHA-1: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`

#### iOS
- **Error**: "sign_in_failed"
  - **Solution**: Ensure `GoogleService-Info.plist` is in `ios/Runner/`
  - Verify bundle ID matches Firebase project
  - Check that Google Sign-In is enabled in Firebase Console

#### Web
- **Error**: "OAuth client ID not found"
  - **Solution**: Verify `googleWebClientId` in `lib/supabase_config.dart`
  - Ensure OAuth consent screen is configured
  - Check that redirect URIs are correct in Google Cloud Console

### Email/Password Issues
- **Error**: "email-already-in-use"
  - User already exists, use sign in instead
- **Error**: "weak-password"
  - Password must be at least 6 characters
- **Error**: "invalid-email"
  - Email format is invalid

## Security Notes

1. **Never commit** `google-services.json` or `GoogleService-Info.plist` with production keys
2. Use different Firebase projects for development and production
3. Keep OAuth Client IDs secure
4. Regularly rotate API keys in production

## Summary

✅ **Email/Password** - Fully configured and working
✅ **Google Sign-In** - Fully configured and working
❌ **Facebook Sign-In** - Removed (not used)

All authentication is handled by Firebase, and user profile data is stored in Supabase database.
