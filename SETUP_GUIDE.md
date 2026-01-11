# Ameen+ Setup Guide

## Architecture Overview

### Firebase
- **Authentication**: User sign in/sign up (Email and Google only)
- **Analytics**: App usage analytics

### Supabase
- **Database**: All post data (deeds), habits, users, communities, etc.
- **Storage**: All files (images, videos, documents) - profile pictures, post media, chat files

## Firebase Setup

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Enable Authentication:
   - **Email/Password** - Required
   - **Google Sign-In** - Required

### 2. Add Firebase to Android
1. Download `google-services.json` from Firebase Console
2. Place it in `android/app/`
3. Already configured in `android/app/build.gradle.kts` and `android/build.gradle.kts`

### 3. Add Firebase to iOS (if needed)
1. Download `GoogleService-Info.plist` from Firebase Console
2. Place it in `ios/Runner/`
3. Configure in Xcode

### 4. Firebase Configuration
- Configuration is handled automatically via `google-services.json` / `GoogleService-Info.plist`
- No manual configuration needed in code

## Supabase Setup

### 1. Create Supabase Project
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Create a new project
3. Note your project URL and anon key

### 2. Update Configuration
Update `lib/supabase_config.dart` with your Supabase credentials:
```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 3. Database Setup

#### Create Deeds Table
```sql
CREATE TABLE deeds (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id),
  user_name TEXT,
  user_photo_url TEXT,
  deed_type TEXT NOT NULL,
  content TEXT NOT NULL,
  arabic_text TEXT,
  translation TEXT,
  reference TEXT,
  category TEXT,
  image_url TEXT,
  media_urls JSONB DEFAULT '[]',
  media_type TEXT,
  interests JSONB DEFAULT '[]',
  is_validated BOOLEAN DEFAULT false,
  validation_reason TEXT,
  validation_confidence NUMERIC,
  likes JSONB DEFAULT '[]',
  comments_count INTEGER DEFAULT 0,
  shares_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for feed query (validated posts)
CREATE INDEX idx_deeds_validated_created ON deeds(is_validated, created_at DESC) 
WHERE is_validated = true;

-- Index for user posts
CREATE INDEX idx_deeds_user_created ON deeds(user_id, created_at DESC);
```

#### Row Level Security (RLS)
```sql
ALTER TABLE deeds ENABLE ROW LEVEL SECURITY;

-- Users can read validated posts or their own
CREATE POLICY "Users can read validated posts or their own"
ON deeds FOR SELECT
USING (is_validated = true OR user_id = auth.uid());

-- Users can create posts (with isValidated: false)
CREATE POLICY "Users can create posts"
ON deeds FOR INSERT
WITH CHECK (auth.uid() = user_id AND is_validated = false);

-- Users can update their own posts (but not validation status)
CREATE POLICY "Users can update their own posts"
ON deeds FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id AND is_validated = OLD.is_validated);

-- Users can delete their own posts
CREATE POLICY "Users can delete their own posts"
ON deeds FOR DELETE
USING (auth.uid() = user_id);
```

### 4. Storage Buckets
Create these buckets in Supabase Storage:
- `avatars` - Profile pictures
- `deeds` - Post images, videos, files
- `media` - Chat media files

Set bucket policies:
- Public read access for avatars and deeds
- Authenticated write access

### 5. Backend Validation (Optional)
See `SUPABASE_BACKEND_VALIDATION.md` for setting up backend validation via:
- Supabase Edge Functions
- Database triggers
- External services

## Installation

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run the App
```bash
flutter run
```

## Testing Checklist

- [ ] Firebase project created
- [ ] `google-services.json` added to `android/app/`
- [ ] Supabase project created
- [ ] Supabase credentials updated in `lib/supabase_config.dart`
- [ ] Database tables created
- [ ] RLS policies configured
- [ ] Storage buckets created
- [ ] Test authentication (sign up/sign in)
- [ ] Test post creation
- [ ] Test file uploads

## Key Points

1. **Firebase**: Authentication only
2. **Supabase**: Database and Storage
3. **Backend Validation**: Posts saved with `is_validated: false`, backend validates
4. **Feed**: Only shows validated posts
5. **Storage**: All files in Supabase Storage buckets
