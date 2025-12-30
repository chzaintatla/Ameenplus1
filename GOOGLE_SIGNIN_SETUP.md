# Google Sign-In Setup Guide

## Your SHA-1 Fingerprint
```
48:33:BC:6B:66:41:9F:C2:68:B7:F4:CC:F5:BC:1E:6A:1F:71:61:94
```

## Steps to Fix Google Sign-In (Error Code 10)

### 1. Add SHA-1 to Firebase Console
1. Go to: https://console.firebase.google.com/
2. Select your project: **ameenplus-86e98**
3. Click the **gear icon** (⚙️) → **Project Settings**
4. Scroll down to **"Your apps"** section
5. Find your **Android app** (`com.example.ameenplus`)
6. Click **"Add fingerprint"** button
7. Paste this SHA-1: `48:33:BC:6B:66:41:9F:C2:68:B7:F4:CC:F5:BC:1E:6A:1F:71:61:94`
8. Click **Save**

### 2. Enable Google Sign-In in Firebase
1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Find **Google** in the list
3. Click on it and toggle **Enable**
4. Add your **Support email** (your email address)
5. Click **Save**

### 3. Download Updated google-services.json
1. In Firebase Console → **Project Settings**
2. Scroll to **"Your apps"** → Android app
3. Click **"Download google-services.json"**
4. Replace `android/app/google-services.json` with the downloaded file

### 4. Rebuild the App
Run these commands:
```bash
flutter clean
flutter pub get
flutter run
```

## Important Notes
- After adding the SHA-1 fingerprint, wait 1-2 minutes for Firebase to update
- Make sure Google Sign-In is enabled in Firebase Authentication
- The google-services.json file must be updated after adding SHA-1

## Verification
After completing these steps, Google Sign-In should work without Error Code 10.

