-- ============================================
-- COMPLETE SUPABASE DATABASE SETUP
-- For Firebase Auth + Supabase Storage/Database
-- ============================================

-- ============================================
-- 1. STORAGE BUCKETS
-- ============================================

-- Avatars Bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880, -- 5MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Deeds Bucket (Posts Media)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'deeds',
  'deeds',
  true,
  52428800, -- 50MB
  ARRAY[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'video/mp4', 'video/quicktime', 'video/x-msvideo',
    'application/pdf',
    'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/m4a',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Media Bucket (Chat Media)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'media',
  'media',
  true,
  10485760, -- 10MB
  ARRAY[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'video/mp4', 'video/quicktime',
    'application/pdf',
    'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/m4a'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Storage Policies for Avatars
DROP POLICY IF EXISTS "Public read access for avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow avatar uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow avatar updates" ON storage.objects;
DROP POLICY IF EXISTS "Allow avatar deletes" ON storage.objects;

CREATE POLICY "Public read access for avatars"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "Allow avatar uploads"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] IS NOT NULL
);

CREATE POLICY "Allow avatar updates"
ON storage.objects FOR UPDATE
USING (bucket_id = 'avatars')
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] IS NOT NULL
);

CREATE POLICY "Allow avatar deletes"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] IS NOT NULL
);

-- Storage Policies for Deeds
DROP POLICY IF EXISTS "Public read access for deeds" ON storage.objects;
DROP POLICY IF EXISTS "Allow deed uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow deed updates" ON storage.objects;
DROP POLICY IF EXISTS "Allow deed deletes" ON storage.objects;

CREATE POLICY "Public read access for deeds"
ON storage.objects FOR SELECT
USING (bucket_id = 'deeds');

CREATE POLICY "Allow deed uploads"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'deeds'
  AND (storage.foldername(name))[1] IS NOT NULL
);

CREATE POLICY "Allow deed updates"
ON storage.objects FOR UPDATE
USING (bucket_id = 'deeds')
WITH CHECK (
  bucket_id = 'deeds'
  AND (storage.foldername(name))[1] IS NOT NULL
);

CREATE POLICY "Allow deed deletes"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'deeds'
  AND (storage.foldername(name))[1] IS NOT NULL
);

-- Storage Policies for Media
DROP POLICY IF EXISTS "Public read access for media" ON storage.objects;
DROP POLICY IF EXISTS "Allow media uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow media updates" ON storage.objects;
DROP POLICY IF EXISTS "Allow media deletes" ON storage.objects;

CREATE POLICY "Public read access for media"
ON storage.objects FOR SELECT
USING (bucket_id = 'media');

CREATE POLICY "Allow media uploads"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'media'
  AND (storage.foldername(name))[1] IS NOT NULL
);

CREATE POLICY "Allow media updates"
ON storage.objects FOR UPDATE
USING (bucket_id = 'media')
WITH CHECK (
  bucket_id = 'media'
  AND (storage.foldername(name))[1] IS NOT NULL
);

CREATE POLICY "Allow media deletes"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'media'
  AND (storage.foldername(name))[1] IS NOT NULL
);

-- ============================================
-- 2. EXTENSIONS
-- ============================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 3. TABLES (Firebase UIDs = TEXT)
-- ============================================
`
-- Users Table
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY, -- Firebase UID
  email TEXT UNIQUE,
  display_name TEXT,
  photo_url TEXT,
  bio TEXT,
  location TEXT,
  birth_date DATE,
  gender TEXT,
  profession TEXT,
  interests TEXT[],
  xp_points INTEGER DEFAULT 0,
  level INTEGER DEFAULT 1,
  badges TEXT[],
  followers_count INTEGER DEFAULT 0,
  following_count INTEGER DEFAULT 0,
  is_email_public BOOLEAN DEFAULT false,
  is_phone_public BOOLEAN DEFAULT false,
  is_profile_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns if table already exists
ALTER TABLE users ADD COLUMN IF NOT EXISTS xp_points INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS level INTEGER DEFAULT 1;
ALTER TABLE users ADD COLUMN IF NOT EXISTS badges TEXT[];
ALTER TABLE users ADD COLUMN IF NOT EXISTS followers_count INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS following_count INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_email_public BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_phone_public BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_profile_public BOOLEAN DEFAULT true;
ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_xp_points ON users(xp_points DESC);

-- Deeds Table (Posts)
CREATE TABLE IF NOT EXISTS deeds (
  id TEXT PRIMARY KEY, -- UUID as TEXT
  user_id TEXT NOT NULL, -- Firebase UID
  user_name TEXT NOT NULL,
  user_photo_url TEXT,
  deed_type TEXT NOT NULL,
  content TEXT NOT NULL,
  arabic_text TEXT,
  translation TEXT,
  reference TEXT,
  category TEXT,
  image_url TEXT,
  media_urls TEXT[] DEFAULT '{}',
  media_type TEXT,
  interests TEXT[] DEFAULT '{}',
  is_validated BOOLEAN DEFAULT true, -- Changed to true for immediate visibility
  validation_reason TEXT,
  validation_confidence REAL,
  likes JSONB DEFAULT '[]', -- Array of user IDs who liked
  comments_count INTEGER DEFAULT 0,
  shares_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns if table already exists
ALTER TABLE deeds ADD COLUMN IF NOT EXISTS media_urls TEXT[] DEFAULT '{}';
ALTER TABLE deeds ADD COLUMN IF NOT EXISTS interests TEXT[] DEFAULT '{}';
ALTER TABLE deeds ADD COLUMN IF NOT EXISTS is_validated BOOLEAN DEFAULT true;
ALTER TABLE deeds ADD COLUMN IF NOT EXISTS validation_reason TEXT;
ALTER TABLE deeds ADD COLUMN IF NOT EXISTS validation_confidence REAL;
ALTER TABLE deeds ADD COLUMN IF NOT EXISTS likes JSONB DEFAULT '[]';
ALTER TABLE deeds ADD COLUMN IF NOT EXISTS comments_count INTEGER DEFAULT 0;
ALTER TABLE deeds ADD COLUMN IF NOT EXISTS shares_count INTEGER DEFAULT 0;
ALTER TABLE deeds ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE deeds ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Drop foreign key if exists (we'll add it after if needed)
ALTER TABLE deeds DROP CONSTRAINT IF EXISTS deeds_user_id_fkey;

CREATE INDEX IF NOT EXISTS idx_deeds_user_id ON deeds(user_id);
CREATE INDEX IF NOT EXISTS idx_deeds_created_at ON deeds(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_deeds_is_validated ON deeds(is_validated);
CREATE INDEX IF NOT EXISTS idx_deeds_deed_type ON deeds(deed_type);
CREATE INDEX IF NOT EXISTS idx_deeds_validated_created ON deeds(is_validated, created_at DESC) WHERE is_validated = true;
CREATE UNIQUE INDEX IF NOT EXISTS idx_deeds_id_unique ON deeds(id);

-- Comments Table
CREATE TABLE IF NOT EXISTS comments (
  id TEXT PRIMARY KEY,
  deed_id TEXT NOT NULL,
  user_id TEXT NOT NULL, -- Firebase UID
  user_name TEXT NOT NULL,
  user_photo_url TEXT,
  content TEXT NOT NULL,
  likes_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns if table already exists
ALTER TABLE comments ADD COLUMN IF NOT EXISTS likes_count INTEGER DEFAULT 0;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE comments ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_comments_deed_id ON comments(deed_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON comments(created_at DESC);

-- Likes Table
CREATE TABLE IF NOT EXISTS likes (
  id TEXT PRIMARY KEY,
  deed_id TEXT NOT NULL,
  user_id TEXT NOT NULL, -- Firebase UID
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(deed_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_likes_deed_id ON likes(deed_id);
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON likes(user_id);

-- Follows Table
CREATE TABLE IF NOT EXISTS follows (
  id TEXT PRIMARY KEY,
  follower_id TEXT NOT NULL, -- Firebase UID
  following_id TEXT NOT NULL, -- Firebase UID
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(follower_id, following_id),
  CHECK (follower_id != following_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower_id ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following_id ON follows(following_id);

-- Habits Table
CREATE TABLE IF NOT EXISTS habits (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL, -- Firebase UID
  habit_type TEXT NOT NULL,
  habit_name TEXT,
  target_value INTEGER DEFAULT 1,
  current_value INTEGER DEFAULT 0,
  last_completed TIMESTAMPTZ,
  streak_days INTEGER DEFAULT 0,
  total_completions INTEGER DEFAULT 0,
  duration_days INTEGER,
  end_date DATE,
  auto_remove_after_completion BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_habits_user_id ON habits(user_id);
CREATE INDEX IF NOT EXISTS idx_habits_habit_type ON habits(habit_type);

-- Communities Table
CREATE TABLE IF NOT EXISTS communities (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  created_by TEXT NOT NULL, -- Firebase UID
  is_public BOOLEAN DEFAULT true,
  members_count INTEGER DEFAULT 0,
  posts_count INTEGER DEFAULT 0,
  last_message JSONB,
  last_message_time TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns if table already exists
ALTER TABLE communities ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE communities ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT true;
ALTER TABLE communities ADD COLUMN IF NOT EXISTS members_count INTEGER DEFAULT 0;
ALTER TABLE communities ADD COLUMN IF NOT EXISTS posts_count INTEGER DEFAULT 0;
ALTER TABLE communities ADD COLUMN IF NOT EXISTS last_message JSONB;
ALTER TABLE communities ADD COLUMN IF NOT EXISTS last_message_time TIMESTAMPTZ;
ALTER TABLE communities ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE communities ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_communities_created_by ON communities(created_by);
CREATE INDEX IF NOT EXISTS idx_communities_created_at ON communities(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_communities_last_message_time ON communities(last_message_time DESC NULLS LAST);

-- Community Members Table
CREATE TABLE IF NOT EXISTS community_members (
  id TEXT PRIMARY KEY,
  community_id TEXT NOT NULL,
  user_id TEXT NOT NULL, -- Firebase UID
  role TEXT DEFAULT 'member',
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(community_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_members_community_id ON community_members(community_id);
CREATE INDEX IF NOT EXISTS idx_community_members_user_id ON community_members(user_id);

-- Messages Table
CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  chat_id TEXT NOT NULL,
  sender_id TEXT NOT NULL, -- Firebase UID
  sender_name TEXT NOT NULL,
  sender_photo_url TEXT,
  content TEXT,
  media_url TEXT,
  media_type TEXT,
  metadata JSONB,
  is_community_message BOOLEAN DEFAULT false,
  read BOOLEAN DEFAULT false,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns if table already exists
ALTER TABLE messages ADD COLUMN IF NOT EXISTS metadata JSONB;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_community_message BOOLEAN DEFAULT false;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS read BOOLEAN DEFAULT false;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS timestamp TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp DESC);

-- Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL, -- Firebase UID
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  action_id TEXT, -- Can be deed_id, chat_id, etc.
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns if table already exists
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_id TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS read BOOLEAN DEFAULT false;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- Favorites Table
CREATE TABLE IF NOT EXISTS favorites (
  id TEXT PRIMARY KEY,
  deed_id TEXT NOT NULL,
  user_id TEXT NOT NULL, -- Firebase UID
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(deed_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_favorites_deed_id ON favorites(deed_id);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);

-- ============================================
-- 4. TRIGGERS
-- ============================================

-- Updated_at Trigger Function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at 
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_deeds_updated_at ON deeds;
CREATE TRIGGER update_deeds_updated_at 
  BEFORE UPDATE ON deeds
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_comments_updated_at ON comments;
CREATE TRIGGER update_comments_updated_at 
  BEFORE UPDATE ON comments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_habits_updated_at ON habits;
CREATE TRIGGER update_habits_updated_at 
  BEFORE UPDATE ON habits
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_communities_updated_at ON communities;
CREATE TRIGGER update_communities_updated_at 
  BEFORE UPDATE ON communities
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comment Count Trigger
CREATE OR REPLACE FUNCTION update_deed_comment_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE deeds SET comments_count = comments_count + 1 WHERE id = NEW.deed_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE deeds SET comments_count = GREATEST(0, comments_count - 1) WHERE id = OLD.deed_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_comment_count ON comments;
CREATE TRIGGER update_comment_count
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW EXECUTE FUNCTION update_deed_comment_count();

-- Like Count Trigger (for likes table)
CREATE OR REPLACE FUNCTION update_deed_like_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE deeds SET likes_count = likes_count + 1 WHERE id = NEW.deed_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE deeds SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.deed_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_like_count ON likes;
DROP TRIGGER IF EXISTS deed_like_counter ON likes;
CREATE TRIGGER deed_like_counter
  AFTER INSERT OR DELETE ON likes
  FOR EACH ROW EXECUTE FUNCTION update_deed_like_count();

-- Message ID Generator Trigger
CREATE OR REPLACE FUNCTION generate_message_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.id IS NULL OR NEW.id = '' THEN
    NEW.id := gen_random_uuid()::TEXT;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_generate_message_id ON messages;
CREATE TRIGGER trigger_generate_message_id
  BEFORE INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION generate_message_id();

-- ============================================
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================
-- Note: Since we use Firebase Auth, we can't use auth.uid()
-- Policies are simplified to allow based on data, not auth context

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE deeds ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- Deeds Policies
DROP POLICY IF EXISTS "Anyone can read validated posts" ON deeds;
DROP POLICY IF EXISTS "Users can create posts" ON deeds;
DROP POLICY IF EXISTS "Users can update posts" ON deeds;
DROP POLICY IF EXISTS "Users can delete posts" ON deeds;

CREATE POLICY "Anyone can read validated posts"
ON deeds FOR SELECT
USING (is_validated = true);

CREATE POLICY "Users can create posts"
ON deeds FOR INSERT
WITH CHECK (true);

CREATE POLICY "Users can update posts"
ON deeds FOR UPDATE
USING (true)
WITH CHECK (true);

CREATE POLICY "Users can delete posts"
ON deeds FOR DELETE
USING (true);

-- Comments Policies
DROP POLICY IF EXISTS "Anyone can read comments" ON comments;
DROP POLICY IF EXISTS "Users can create comments" ON comments;
DROP POLICY IF EXISTS "Users can update comments" ON comments;
DROP POLICY IF EXISTS "Users can delete comments" ON comments;

CREATE POLICY "Anyone can read comments"
ON comments FOR SELECT
USING (true);

CREATE POLICY "Users can create comments"
ON comments FOR INSERT
WITH CHECK (true);

CREATE POLICY "Users can update comments"
ON comments FOR UPDATE
USING (true)
WITH CHECK (true);

CREATE POLICY "Users can delete comments"
ON comments FOR DELETE
USING (true);

-- Likes Policies
DROP POLICY IF EXISTS "Anyone can read likes" ON likes;
DROP POLICY IF EXISTS "Users can create likes" ON likes;
DROP POLICY IF EXISTS "Users can delete likes" ON likes;

CREATE POLICY "Anyone can read likes"
ON likes FOR SELECT
USING (true);

CREATE POLICY "Users can create likes"
ON likes FOR INSERT
WITH CHECK (true);

CREATE POLICY "Users can delete likes"
ON likes FOR DELETE
USING (true);

-- Users Policies (basic - adjust as needed)
DROP POLICY IF EXISTS "Anyone can read public profiles" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;

CREATE POLICY "Anyone can read public profiles"
ON users FOR SELECT
USING (is_profile_public = true);

CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
USING (true)
WITH CHECK (true);

-- Messages Policies
DROP POLICY IF EXISTS "Users can read messages" ON messages;
DROP POLICY IF EXISTS "Users can create messages" ON messages;

CREATE POLICY "Users can read messages"
ON messages FOR SELECT
USING (true);

CREATE POLICY "Users can create messages"
ON messages FOR INSERT
WITH CHECK (true);

-- Notifications Policies
DROP POLICY IF EXISTS "Users can read own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;

CREATE POLICY "Users can read own notifications"
ON notifications FOR SELECT
USING (true);

CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
USING (true)
WITH CHECK (true);

-- ============================================
-- 6. REAL-TIME PUBLICATION
-- ============================================

-- Set replica identity for real-time
ALTER TABLE users REPLICA IDENTITY FULL;
ALTER TABLE deeds REPLICA IDENTITY FULL;
ALTER TABLE comments REPLICA IDENTITY FULL;
ALTER TABLE likes REPLICA IDENTITY FULL;
ALTER TABLE messages REPLICA IDENTITY FULL;
ALTER TABLE notifications REPLICA IDENTITY FULL;
ALTER TABLE follows REPLICA IDENTITY FULL;
ALTER TABLE favorites REPLICA IDENTITY FULL;
ALTER TABLE habits REPLICA IDENTITY FULL;
ALTER TABLE communities REPLICA IDENTITY FULL;
ALTER TABLE community_members REPLICA IDENTITY FULL;

-- Add tables to real-time publication (only if not already added)
DO $$
DECLARE
  table_name TEXT;
  tables_to_add TEXT[] := ARRAY[
    'users', 'deeds', 'comments', 'likes', 'messages', 
    'notifications', 'follows', 'favorites', 'habits', 
    'communities', 'community_members'
  ];
  existing_tables TEXT[];
BEGIN
  -- Get list of tables already in publication
  SELECT array_agg(tablename::TEXT) INTO existing_tables
  FROM pg_publication_tables
  WHERE pubname = 'supabase_realtime';
  
  -- Add each table only if not already in publication
  FOREACH table_name IN ARRAY tables_to_add
  LOOP
    IF existing_tables IS NULL OR NOT (table_name = ANY(existing_tables)) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', table_name);
    END IF;
  END LOOP;
END $$;

-- ============================================
-- 7. DATA CLEANUP (Run once)
-- ============================================

-- Remove duplicate deeds based on id
WITH ranked_deeds AS (
  SELECT id, 
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY created_at ASC) as rn
  FROM deeds
)
DELETE FROM deeds
WHERE id IN (
  SELECT id FROM ranked_deeds WHERE rn > 1
);

-- Set all existing posts to validated
UPDATE deeds 
SET is_validated = true 
WHERE is_validated IS NULL OR is_validated = false;

-- ============================================
-- VERIFICATION QUERIES (Optional - run to verify)
-- ============================================

-- Check storage buckets
-- SELECT id, name, public, file_size_limit FROM storage.buckets WHERE id IN ('avatars', 'deeds', 'media');

-- Check table structures
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;

-- Check validated posts count
-- SELECT COUNT(*) as validated_posts FROM deeds WHERE is_validated = true;

-- Check for duplicates
-- SELECT id, COUNT(*) as count FROM deeds GROUP BY id HAVING COUNT(*) > 1;

