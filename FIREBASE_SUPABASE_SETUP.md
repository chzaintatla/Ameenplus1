# Firebase and Supabase Setup Guide

## Architecture Overview

- **Firebase**: Authentication + Firestore Database
- **Supabase**: Storage only (images, videos, files)

## Firebase Setup

### 1. Firestore Security Rules

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Firestore Database** → **Rules**
4. Copy the contents of `firestore.rules` file
5. Paste into the rules editor
6. Click **Publish**

### 2. Firestore Indexes

Create these composite indexes in Firestore:

#### Deeds Collection
- Collection: `deeds`
- Fields: `isValidated` (Ascending), `createdAt` (Descending)
- Query scope: Collection

- Collection: `deeds`
- Fields: `userId` (Ascending), `createdAt` (Descending)
- Query scope: Collection

#### Comments Collection
- Collection: `comments`
- Fields: `deedId` (Ascending), `createdAt` (Descending)
- Query scope: Collection

#### Notifications Collection
- Collection: `notifications`
- Fields: `userId` (Ascending), `createdAt` (Descending)
- Query scope: Collection
- Fields: `userId` (Ascending), `isRead` (Ascending), `createdAt` (Descending)
- Query scope: Collection

#### Communities Collection
- Collection: `communities`
- Fields: `isPublic` (Ascending), `createdAt` (Descending)
- Query scope: Collection

#### Messages Collection
- Collection: `chats/{chatId}/messages`
- Fields: `createdAt` (Ascending)
- Query scope: Collection

### 3. Firebase Authentication

Enable these sign-in methods:
- ✅ Email/Password
- ✅ Google Sign-In

### 4. Firebase Configuration Files

**Android:**
- Download `google-services.json` from Firebase Console
- Place in `android/app/`

**iOS:**
- Download `GoogleService-Info.plist` from Firebase Console
- Place in `ios/Runner/`

## Supabase Setup

### 1. Create Storage Buckets

Run the SQL commands from `supabase_storage_policies.sql` in your Supabase SQL Editor:

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **SQL Editor**
4. Create a new query
5. Copy and paste the contents of `supabase_storage_policies.sql`
6. Click **Run**

### 2. Verify Buckets

After running the SQL, verify buckets are created:

1. Go to **Storage** in Supabase Dashboard
2. You should see three buckets:
   - `avatars` - Profile pictures
   - `deeds` - Post media
   - `media` - Chat media

### 3. Bucket Configuration

Each bucket should have:
- **Public**: Enabled (for public read access)
- **File size limits**: As specified in SQL
- **Allowed MIME types**: As specified in SQL

### 4. Storage Policies

The SQL file creates these policies:

#### Avatars Bucket
- ✅ Public read access
- ✅ Authenticated users can upload to their own folder (`userId/filename`)
- ✅ Users can update/delete their own files

#### Deeds Bucket
- ✅ Public read access
- ✅ Authenticated users can upload to their own folder (`userId/filename`)
- ✅ Users can update/delete their own files
- ✅ Supports: Images, Videos, PDFs, Audio, Documents

#### Media Bucket
- ✅ Public read access
- ✅ Authenticated users can upload to their own folder (`userId/filename`)
- ✅ Users can update/delete their own files
- ✅ Supports: Images, Videos, PDFs, Audio

### 5. File Path Structure

Files are stored with this structure:
```
bucket_name/
  └── userId/
      └── filename.ext
```

Example:
- `avatars/user123/profile.jpg`
- `deeds/user123/post-image.jpg`
- `media/user123/chat-video.mp4`

## Testing

### Test Firebase Rules

1. Try to read a deed → Should work if validated or own deed
2. Try to create a deed → Should work if authenticated
3. Try to update validation status → Should fail (only via Cloud Functions)
4. Try to delete someone else's deed → Should fail

### Test Supabase Storage

1. Upload a profile picture → Should work if authenticated
2. Try to upload to someone else's folder → Should fail
3. Try to read any file → Should work (public read)
4. Try to delete someone else's file → Should fail

## Security Notes

1. **Firebase Rules**: Always test rules in the Firebase Console Rules Playground
2. **Supabase Policies**: Files are organized by user ID in folders for security
3. **Validation**: Backend validation should be done via Cloud Functions (not client-side)
4. **File Size**: Enforced at both client and storage level
5. **MIME Types**: Restricted to prevent malicious file uploads

## Troubleshooting

### Firebase Rules Issues
- Check that user is authenticated: `request.auth != null`
- Verify user ID matches: `request.auth.uid == userId`
- Test in Rules Playground before deploying

### Supabase Storage Issues
- Verify bucket exists: Check Storage dashboard
- Check policies: Run verification queries from SQL file
- Verify file path structure: Must be `userId/filename`
- Check authentication: User must be logged in via Firebase

## File Upload Flow

1. User selects file (camera or gallery)
2. File validated (size, type) on client
3. File uploaded to Supabase Storage: `bucket/userId/filename`
4. Public URL returned
5. URL stored in Firebase Firestore with post data

## Next Steps

1. Deploy Firestore rules
2. Create Firestore indexes
3. Run Supabase storage SQL
4. Test file uploads
5. Test database operations
6. Set up Cloud Functions for backend validation (optional)
