# Storage and Database Architecture

## Overview

This app uses a hybrid architecture:
- **Firebase Firestore**: Database for all content and data
- **Supabase Storage**: Storage for all files (images, videos, documents)
- **Firebase Auth**: Authentication (Email and Google only)

## Architecture

### Firebase
- **Authentication**: Email/Password and Google Sign-In
- **Firestore Database**: All content data (deeds, users, comments, etc.)
- **Analytics**: App usage tracking

### Supabase
- **Storage Only**: All file uploads (images, videos, documents)
  - Profile pictures → `avatars` bucket
  - Post media → `deeds` bucket
  - Chat media → `media` bucket

## Image Selection

The app supports image selection from:
1. **Camera** - Take photos/videos directly
2. **Gallery** - Select from device gallery

### Implementation
- `create_deed_screen.dart` - Supports both camera and gallery for images/videos
- `edit_profile_screen.dart` - Supports both camera and gallery for profile images
- `camera_screen.dart` - Full camera interface with gallery option

## Storage Flow

1. User selects image/video from camera or gallery
2. File is uploaded to **Supabase Storage** via `StorageService`
3. Public URL is returned
4. URL is stored in **Firebase Firestore** along with post content

## Storage Service

All storage operations use `StorageService` which:
- Uploads files to Supabase Storage
- Returns public URLs
- Handles file deletion
- Supports multiple buckets (avatars, deeds, media)

## Database Migration Status

⚠️ **Note**: Currently, some repositories still use Supabase for database operations. These need to be migrated to Firebase Firestore:

- [ ] `deeds_repository.dart` - Migrate to Firestore
- [ ] `user_profile_repository.dart` - Migrate to Firestore
- [ ] `comments_repository.dart` - Migrate to Firestore
- [ ] `notification_repository.dart` - Migrate to Firestore
- [ ] `friends_repository.dart` - Migrate to Firestore
- [ ] `follow_repository.dart` - Migrate to Firestore

## Setup Instructions

### 1. Firebase Setup
1. Create Firebase project
2. Enable Firestore Database
3. Enable Authentication (Email/Password and Google)
4. Download `google-services.json` for Android
5. Download `GoogleService-Info.plist` for iOS

### 2. Supabase Setup
1. Create Supabase project
2. Create storage buckets:
   - `avatars` - Public read, authenticated write
   - `deeds` - Public read, authenticated write
   - `media` - Public read, authenticated write
3. Update `lib/supabase_config.dart` with your credentials

### 3. Storage Bucket Policies

For each bucket, set policies:
```sql
-- Allow public read access
CREATE POLICY "Public read access" ON storage.objects
FOR SELECT USING (bucket_id = 'avatars');

-- Allow authenticated users to upload
CREATE POLICY "Authenticated upload" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'avatars' AND
  auth.role() = 'authenticated'
);

-- Allow users to delete their own files
CREATE POLICY "Users can delete own files" ON storage.objects
FOR DELETE USING (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
```

## Current Status

✅ **Completed:**
- Image picker supports camera and gallery
- All files uploaded to Supabase Storage
- StorageService configured for Supabase
- Firebase Firestore dependency added

⚠️ **In Progress:**
- Migrating repositories from Supabase to Firestore

## Usage Examples

### Upload Image to Supabase Storage
```dart
final imageUrl = await StorageService.uploadFile(
  bucket: 'deeds',
  filePath: 'userId/image.jpg',
  file: imageFile,
  contentType: 'image/jpeg',
);
```

### Store Data in Firebase Firestore
```dart
await FirebaseFirestore.instance
  .collection('deeds')
  .doc(deedId)
  .set({
    'content': content,
    'imageUrl': imageUrl, // URL from Supabase Storage
    'userId': userId,
    'createdAt': FieldValue.serverTimestamp(),
  });
```
