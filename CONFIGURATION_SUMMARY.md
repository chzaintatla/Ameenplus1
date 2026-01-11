# Configuration Summary

## Files Created

### 1. `firestore.rules`
- **Purpose**: Firebase Firestore security rules
- **Location**: Deploy to Firebase Console → Firestore → Rules
- **Features**:
  - User authentication checks
  - Owner validation
  - Backend validation protection (isValidated field)
  - Collection-specific rules (deeds, comments, users, etc.)

### 2. `firestore.indexes.json`
- **Purpose**: Firestore composite indexes
- **Location**: Import to Firebase Console → Firestore → Indexes
- **Indexes**: 10 composite indexes for optimal query performance

### 3. `supabase_storage_policies.sql`
- **Purpose**: Supabase Storage bucket policies
- **Location**: Run in Supabase Dashboard → SQL Editor
- **Features**:
  - Creates 3 buckets: `avatars`, `deeds`, `media`
  - Public read access
  - Path-based security (userId/filename.ext)
  - File size limits
  - MIME type restrictions

### 4. `FIREBASE_SUPABASE_SETUP.md`
- **Purpose**: Detailed setup instructions
- **Content**: Step-by-step guide for both Firebase and Supabase

### 5. `QUICK_SETUP_GUIDE.md`
- **Purpose**: Quick reference for setup
- **Content**: Condensed setup steps

## Architecture

```
┌─────────────────────────────────────────┐
│           Firebase Services              │
├─────────────────────────────────────────┤
│  • Authentication (Email + Google)      │
│  • Firestore Database (All data)        │
│  • Analytics                            │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│          Supabase Services               │
├─────────────────────────────────────────┤
│  • Storage Only (Images, Videos, Files) │
│    - avatars bucket                     │
│    - deeds bucket                       │
│    - media bucket                       │
└─────────────────────────────────────────┘
```

## Security Model

### Firebase Firestore
- ✅ Authentication required for writes
- ✅ Users can only modify their own data
- ✅ Backend validation protected (isValidated field)
- ✅ Public read for validated content

### Supabase Storage
- ✅ Public read access (for performance)
- ✅ Path-based security (userId/filename.ext)
- ✅ App-side validation (userId must match Firebase Auth user)
- ✅ File size limits enforced
- ✅ MIME type restrictions

## File Upload Flow

```
User selects image/video
    ↓
App validates userId matches Firebase Auth
    ↓
Upload to Supabase: bucket/userId/filename.ext
    ↓
Get public URL
    ↓
Store URL + content in Firebase Firestore
```

## Setup Checklist

### Firebase
- [ ] Deploy `firestore.rules` to Firebase Console
- [ ] Import `firestore.indexes.json` to create indexes
- [ ] Enable Email/Password authentication
- [ ] Enable Google Sign-In
- [ ] Add `google-services.json` (Android)
- [ ] Add `GoogleService-Info.plist` (iOS)

### Supabase
- [ ] Run `supabase_storage_policies.sql` in SQL Editor
- [ ] Verify 3 buckets created (avatars, deeds, media)
- [ ] Verify policies applied
- [ ] Test file upload

## Important Notes

1. **Firebase Auth + Supabase Storage**: 
   - Supabase Storage policies use path-based security
   - App code must validate userId matches Firebase Auth user
   - This is secure because files are organized by userId

2. **Backend Validation**:
   - Deeds are created with `isValidated: false`
   - Only backend (Cloud Functions) can update validation status
   - Frontend cannot change validation status

3. **File Organization**:
   - All files: `bucket/userId/filename.ext`
   - Example: `deeds/user123/post-image.jpg`
   - This structure enables path-based security

## Testing

### Test Firestore Rules
1. Try reading a deed → Should work
2. Try creating a deed → Should work if authenticated
3. Try updating validation → Should fail (backend only)
4. Try deleting someone else's deed → Should fail

### Test Supabase Storage
1. Upload profile picture → Should work
2. Check file path → Should be `userId/filename.ext`
3. Try reading file → Should work (public read)
4. Verify file appears in Supabase Storage dashboard

## Support

If you encounter issues:
1. Check Firebase Console for rule errors
2. Check Supabase Dashboard for policy errors
3. Verify file paths include userId
4. Test in Rules Playground (Firebase)
