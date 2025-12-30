# Firebase Setup Guide for Ameen+ App

This guide will walk you through setting up Firebase for your Ameen+ Flutter application.

## Prerequisites

1. A Google account
2. Flutter SDK installed
3. Android Studio / VS Code with Flutter extensions
4. Android device/emulator or iOS device/simulator

---

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or **"Create a project"**
3. Enter project name: `ameenplus` (or your preferred name)
4. Enable/disable Google Analytics (optional)
5. Click **"Create project"**
6. Wait for project creation, then click **"Continue"**

---

## Step 2: Add Android App to Firebase

1. In Firebase Console, click the **Android icon** (or go to Project Settings → Your apps)
2. Enter Android package name:
   - Check your `android/app/build.gradle.kts` file
   - Look for `applicationId` (usually `com.example.ameen_mobile_app` or similar)
   - Enter it exactly as shown
3. Enter App nickname: `Ameen+ Android`
4. Enter Debug signing certificate SHA-1 (for Google Sign-In):
   - **Windows:**
     ```bash
     keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
     ```
   - **Mac/Linux:**
     ```bash
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```
   - Copy the SHA-1 fingerprint (looks like: `AA:BB:CC:DD:EE:FF:...`)
5. Click **"Register app"**
6. Download `google-services.json`
7. Place it in: `android/app/google-services.json`
   - **Important:** Replace the existing file if it exists

---

## Step 3: Add iOS App to Firebase (if needed)

1. In Firebase Console, click the **iOS icon**
2. Enter iOS bundle ID:
   - Check `ios/Runner.xcodeproj` or `ios/Runner/Info.plist`
   - Look for `CFBundleIdentifier`
3. Enter App nickname: `Ameen+ iOS`
4. Click **"Register app"**
5. Download `GoogleService-Info.plist`
6. Place it in: `ios/Runner/GoogleService-Info.plist`
   - Open Xcode and drag the file into the Runner folder

---

## Step 4: Enable Firebase Services

### 4.1 Authentication

1. Go to **Authentication** → **Sign-in method**
2. Enable the following providers:
   - ✅ **Email/Password** - Click "Enable" → Save
   - ✅ **Google** - Click "Enable" → Add support email → Save
   - ✅ **Facebook** - Click "Enable" → Add App ID and App Secret → Save
   - ✅ **Phone** - Click "Enable" → Save

**For Google Sign-In:**
- Go to [Google Cloud Console](https://console.cloud.google.com/)
- Select your Firebase project
- Go to **APIs & Services** → **Credentials**
- Copy the **Web client ID** (OAuth 2.0 Client ID)
- This will be used in your app configuration

**For Facebook Sign-In:**
- Go to [Facebook Developers](https://developers.facebook.com/)
- Create a new app
- Get App ID and App Secret
- Add them to Firebase Authentication

### 4.2 Firestore Database

1. Go to **Firestore Database**
2. Click **"Create database"**
3. Choose **"Start in test mode"** (for development)
   - ⚠️ **Important:** Change to production mode later with proper security rules
4. Select location (choose closest to your users)
5. Click **"Enable"**

### 4.3 Storage

1. Go to **Storage**
2. Click **"Get started"**
3. Start in **test mode** (for development)
4. Select location (same as Firestore)
5. Click **"Done"**

### 4.4 Cloud Messaging (for Push Notifications)

1. Go to **Cloud Messaging**
2. No additional setup needed for basic functionality
3. For production, configure FCM server key if needed

---

## Step 5: Configure Firestore Security Rules

Go to **Firestore Database** → **Rules** tab and replace with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Deeds collection
    match /deeds/{deedId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    // Comments subcollection
    match /deeds/{deedId}/comments/{commentId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow delete: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    // Communities collection
    match /communities/{communityId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        (resource.data.creatorId == request.auth.uid || 
         request.auth.uid in resource.data.admins);
    }
    
    // Chats collection
    match /chats/{chatId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participants;
      allow create: if request.auth != null;
    }
    
    // Messages subcollection
    match /chats/{chatId}/messages/{messageId} {
      allow read, write: if request.auth != null;
    }
    
    // Friend requests
    match /friend_requests/{requestId} {
      allow read: if request.auth != null && 
        (resource.data.senderId == request.auth.uid || 
         resource.data.receiverId == request.auth.uid);
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        resource.data.receiverId == request.auth.uid;
    }
    
    // Notifications
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    // Habits
    match /habits/{habitId} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    // Moods
    match /moods/{moodId} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    // Leaderboard
    match /leaderboard_public/{userId} {
      allow read: if true; // Public read
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## Step 6: Configure Storage Security Rules

Go to **Storage** → **Rules** tab and replace with:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile pictures
    match /profiles/{userId}/{fileName} {
      allow read: if true; // Public read
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Deed images
    match /deeds/{deedId}/{fileName} {
      allow read: if true; // Public read
      allow write: if request.auth != null;
    }
    
    // Community images
    match /communities/{communityId}/{fileName} {
      allow read: if true; // Public read
      allow write: if request.auth != null;
    }
  }
}
```

---

## Step 7: Create Firestore Indexes

Go to **Firestore Database** → **Indexes** tab and create these composite indexes:

### Index 1: Communities
- Collection: `communities`
- Fields:
  - `isPublic` (Ascending)
  - `createdAt` (Descending)
- Query scope: Collection

### Index 2: Communities Members
- Collection: `communities`
- Fields:
  - `members` (Array Contains)
  - `createdAt` (Descending)
- Query scope: Collection

### Index 3: Chats
- Collection: `chats`
- Fields:
  - `participants` (Array Contains)
  - `lastMessageTime` (Descending)
- Query scope: Collection

### Index 4: Notifications
- Collection: `notifications`
- Fields:
  - `userId` (Ascending)
  - `createdAt` (Descending)
- Query scope: Collection

### Index 5: Notifications Unread
- Collection: `notifications`
- Fields:
  - `userId` (Ascending)
  - `read` (Ascending)
- Query scope: Collection

### Index 6: Friend Requests
- Collection: `friend_requests`
- Fields:
  - `receiverId` (Ascending)
  - `status` (Ascending)
  - `createdAt` (Descending)
- Query scope: Collection

### Index 7: Users Leaderboard
- Collection: `users`
- Fields:
  - `isProfilePublic` (Ascending)
  - `xp` (Descending)
- Query scope: Collection

**Note:** Firebase will automatically prompt you to create indexes when you run queries that need them. You can also create them manually in the Firebase Console.

---

## Step 8: Generate Firebase Options File

Run this command in your project root:

```bash
flutter pub add firebase_core
flutter pub add firebase_auth
flutter pub add cloud_firestore
flutter pub add firebase_storage
flutter pub add firebase_messaging
flutter pub add firebase_analytics

# Generate firebase_options.dart
flutterfire configure
```

This will:
1. Detect your Firebase project
2. Generate `lib/firebase_options.dart` with your configuration
3. Configure both Android and iOS automatically

**Alternative (Manual):**
If `flutterfire configure` doesn't work, you can manually create the file using the Firebase CLI:

```bash
# Install Firebase CLI (if not installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize FlutterFire
firebase init

# Or use FlutterFire CLI
dart pub global activate flutterfire_cli
flutterfire configure
```

---

## Step 9: Verify Configuration

### Check Files Exist:
- ✅ `android/app/google-services.json`
- ✅ `ios/Runner/GoogleService-Info.plist` (if iOS)
- ✅ `lib/firebase_options.dart`

### Check Android Configuration:

1. Open `android/build.gradle.kts`:
   ```kotlin
   buildscript {
       dependencies {
           classpath("com.google.gms:google-services:4.4.0")
       }
   }
   ```

2. Open `android/app/build.gradle.kts`:
   ```kotlin
   plugins {
       id("com.android.application")
       id("kotlin-android")
       id("dev.flutter.flutter-gradle-plugin")
       id("com.google.gms.google-services") // Add this
   }
   ```

### Check iOS Configuration (if applicable):

1. Open `ios/Podfile` and ensure Firebase pods are included
2. Run: `cd ios && pod install`

---

## Step 10: Test Firebase Connection

1. Run your app:
   ```bash
   flutter run
   ```

2. Try signing up with email/password
3. Check Firebase Console → Authentication → Users (should see new user)
4. Check Firestore Database → Collections (should see `users` collection)

---

## Step 11: Create Sample Data (Optional)

You can create sample communities in Firestore:

1. Go to **Firestore Database**
2. Click **"Start collection"**
3. Collection ID: `communities`
4. Add document with fields:
   - `name`: "New Muslims Support"
   - `description`: "Events · Reminders · Q&A"
   - `creatorId`: (your user ID)
   - `members`: [] (array)
   - `admins`: [] (array)
   - `category`: "Support"
   - `isPublic`: true
   - `postsCount`: 0
   - `eventsCount`: 0
   - `createdAt`: (timestamp)
   - `updatedAt`: (timestamp)

---

## Troubleshooting

### Error: "MissingPluginException"
```bash
flutter clean
flutter pub get
flutter run
```

### Error: "Google Sign-In not working"
1. Verify SHA-1 fingerprint is added in Firebase Console
2. Download updated `google-services.json`
3. Rebuild app: `flutter clean && flutter run`

### Error: "Firestore permission denied"
1. Check Firestore Security Rules
2. Ensure user is authenticated
3. Verify rules allow the operation

### Error: "Storage permission denied"
1. Check Storage Security Rules
2. Ensure user is authenticated
3. Verify file path matches rule pattern

### Error: "Index missing"
1. Go to Firestore → Indexes
2. Create the missing index (Firebase will provide a link)
3. Wait for index to build (can take a few minutes)

---

## Production Checklist

Before deploying to production:

- [ ] Change Firestore rules from "test mode" to production rules
- [ ] Change Storage rules from "test mode" to production rules
- [ ] Add production SHA-1 fingerprint (for release builds)
- [ ] Enable App Check (optional, for security)
- [ ] Set up Firebase Analytics events
- [ ] Configure Cloud Messaging for push notifications
- [ ] Set up Firebase Crashlytics (optional)
- [ ] Review and optimize Firestore indexes
- [ ] Set up Firebase Performance Monitoring (optional)

---

## Additional Resources

- [Firebase Flutter Documentation](https://firebase.flutter.dev/)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase Storage Rules](https://firebase.google.com/docs/storage/security)
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/)

---

## Support

If you encounter issues:
1. Check Firebase Console for error logs
2. Check Flutter console for detailed error messages
3. Verify all configuration files are in place
4. Ensure Firebase services are enabled

Good luck with your Ameen+ app! 🚀

