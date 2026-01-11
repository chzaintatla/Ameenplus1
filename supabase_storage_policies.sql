-- ============================================
-- Supabase Storage Policies for Firebase Auth
-- ============================================
-- Note: Since we use Firebase Auth (not Supabase Auth),
-- we use path-based security with anon key
-- Files must be stored as: userId/filename.ext
-- ============================================

-- ============================================
-- 1. AVATARS BUCKET (Profile Pictures)
-- ============================================

-- Create the avatars bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true, -- Public bucket for profile pictures
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Policy: Public read access for avatars
CREATE POLICY "Public read access for avatars"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Policy: Allow uploads via anon key (Firebase Auth users)
-- Security: App code validates userId matches Firebase Auth user
-- Path structure: userId/filename.ext
CREATE POLICY "Allow avatar uploads"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' AND
  -- Path must have userId as first folder
  (storage.foldername(name))[1] IS NOT NULL
);

-- Policy: Allow updates (users can update their own files)
-- App code must validate userId matches
CREATE POLICY "Allow avatar updates"
ON storage.objects FOR UPDATE
USING (bucket_id = 'avatars')
WITH CHECK (
  bucket_id = 'avatars' AND
  (storage.foldername(name))[1] IS NOT NULL
);

-- Policy: Allow deletes (users can delete their own files)
-- App code must validate userId matches
CREATE POLICY "Allow avatar deletes"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'avatars' AND
  (storage.foldername(name))[1] IS NOT NULL
);

-- ============================================
-- 2. DEEDS BUCKET (Post Images, Videos, Files)
-- ============================================

-- Create the deeds bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'deeds',
  'deeds',
  true, -- Public bucket for post media
  52428800, -- 50MB limit
  ARRAY[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'video/mp4', 'video/quicktime', 'video/x-msvideo',
    'application/pdf',
    'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/m4a',
    'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Policy: Public read access for deeds
CREATE POLICY "Public read access for deeds"
ON storage.objects FOR SELECT
USING (bucket_id = 'deeds');

-- Policy: Allow uploads via anon key
-- Security: App code validates userId matches Firebase Auth user
CREATE POLICY "Allow deed uploads"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'deeds' AND
  (storage.foldername(name))[1] IS NOT NULL
);

-- Policy: Allow updates
CREATE POLICY "Allow deed updates"
ON storage.objects FOR UPDATE
USING (bucket_id = 'deeds')
WITH CHECK (
  bucket_id = 'deeds' AND
  (storage.foldername(name))[1] IS NOT NULL
);

-- Policy: Allow deletes
CREATE POLICY "Allow deed deletes"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'deeds' AND
  (storage.foldername(name))[1] IS NOT NULL
);

-- ============================================
-- 3. MEDIA BUCKET (Chat Media Files)
-- ============================================

-- Create the media bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'media',
  'media',
  true, -- Public bucket for chat media
  10485760, -- 10MB limit for chat files
  ARRAY[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'video/mp4', 'video/quicktime',
    'application/pdf',
    'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/m4a'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Policy: Public read access for media
CREATE POLICY "Public read access for media"
ON storage.objects FOR SELECT
USING (bucket_id = 'media');

-- Policy: Allow uploads via anon key
CREATE POLICY "Allow media uploads"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'media' AND
  (storage.foldername(name))[1] IS NOT NULL
);

-- Policy: Allow updates
CREATE POLICY "Allow media updates"
ON storage.objects FOR UPDATE
USING (bucket_id = 'media')
WITH CHECK (
  bucket_id = 'media' AND
  (storage.foldername(name))[1] IS NOT NULL
);

-- Policy: Allow deletes
CREATE POLICY "Allow media deletes"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'media' AND
  (storage.foldername(name))[1] IS NOT NULL
);

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check if buckets exist
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id IN ('avatars', 'deeds', 'media');

-- Check all storage policies
SELECT 
  policyname,
  cmd,
  bucket_id,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
ORDER BY bucket_id, cmd;

-- ============================================
-- IMPORTANT NOTES
-- ============================================
-- 1. Since we use Firebase Auth, Supabase RLS can't verify user identity
-- 2. Security is enforced by:
--    - Path structure: userId/filename.ext
--    - App code validation: userId must match Firebase Auth user
--    - File size limits: Enforced at bucket level
--    - MIME type restrictions: Enforced at bucket level
-- 3. For production, consider using Supabase Edge Functions
--    to validate Firebase Auth tokens before allowing uploads
