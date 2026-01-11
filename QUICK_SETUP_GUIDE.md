# Quick Setup Guide - Firebase & Supabase

## Step 1: Firebase Firestore Rules

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Firestore Database** → **Rules** tab
4. Copy entire content from `firestore.rules` file
5. Paste and click **Publish**

## Step 2: Firebase Firestore Indexes

1. In Firebase Console, go to **Firestore Database** → **Indexes** tab
2. Click **Import** button
3. Select `firestore.indexes.json` file
4. Click **Import**
5. Wait for indexes to build (may take a few minutes)

**OR** manually create indexes:
- Go to **Firestore Database** → **Indexes** → **Create Index**
- Create each index as listed in `FIREBASE_SUPABASE_SETUP.md`

## Step 3: Supabase Storage Buckets & Policies

1. Open [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **SQL Editor**
4. Click **New Query**
5. Copy entire content from `supabase_storage_policies.sql` file
6. Paste and click **Run** (or press Ctrl+Enter)
7. Verify success message

## Step 4: Verify Setup

### Verify Supabase Buckets
1. In Supabase Dashboard, go to **Storage**
2. You should see 3 buckets:
   - ✅ `avatars`
   - ✅ `deeds`
   - ✅ `media`

### Verify Supabase Policies
Run this query in Supabase SQL Editor:
```sql
SELECT policyname, cmd, bucket_id
FROM pg_policies p
JOIN storage.objects o ON true
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
GROUP BY policyname, cmd, bucket_id
ORDER BY bucket_id, cmd;
```

### Verify Firebase Rules
1. In Firebase Console, go to **Firestore Database** → **Rules**
2. Click **Rules Playground**
3. Test a few scenarios:
   - Read a deed (should work)
   - Create a deed (should work if authenticated)
   - Update validation status (should fail)

## Step 5: Test File Upload

1. Run your Flutter app
2. Try uploading a profile picture
3. Check Supabase Storage → `avatars` bucket
4. Verify file appears with path: `userId/filename.jpg`

## Troubleshooting

### Supabase Storage Issues
- **Error**: "Bucket not found"
  - Solution: Run the SQL file again to create buckets

- **Error**: "Policy violation"
  - Solution: Check that policies were created (run verification query)

- **Error**: "File too large"
  - Solution: Check bucket file_size_limit matches your needs

### Firebase Rules Issues
- **Error**: "Missing or insufficient permissions"
  - Solution: Check user is authenticated and rules are correct
  - Use Rules Playground to test

- **Error**: "Index required"
  - Solution: Create the required index in Firestore

## File Structure

```
Your Project/
├── firestore.rules              # Firebase Firestore security rules
├── firestore.indexes.json      # Firestore composite indexes
├── supabase_storage_policies.sql  # Supabase storage policies
├── FIREBASE_SUPABASE_SETUP.md    # Detailed setup guide
└── QUICK_SETUP_GUIDE.md          # This file
```

## Security Checklist

- [ ] Firestore rules deployed
- [ ] Firestore indexes created
- [ ] Supabase buckets created
- [ ] Supabase policies applied
- [ ] Tested file upload
- [ ] Tested file read
- [ ] Tested file delete
- [ ] Verified users can only access their own files

## Support

If you encounter issues:
1. Check Firebase Console → Firestore → Rules for errors
2. Check Supabase Dashboard → Storage → Policies
3. Review error messages in app logs
4. Test in Rules Playground (Firebase) or SQL Editor (Supabase)
