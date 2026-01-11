# Supabase Backend Validation Setup

## Overview
Posts are stored in **Supabase database** and validated on the backend. When a user creates a post:
1. Post is saved to Supabase with `is_validated: false`
2. Backend (Supabase Edge Function or external service) validates the content
3. If valid, backend sets `is_validated: true` and awards XP
4. Only validated posts appear in the feed

## Database Structure

### Deeds Table Schema
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

## Row Level Security (RLS) Policies

### Enable RLS
```sql
ALTER TABLE deeds ENABLE ROW LEVEL SECURITY;
```

### Policies

#### 1. Users can read validated posts (or their own posts)
```sql
CREATE POLICY "Users can read validated posts or their own"
ON deeds
FOR SELECT
USING (
  is_validated = true 
  OR user_id = auth.uid()
);
```

#### 2. Users can create posts (with isValidated: false)
```sql
CREATE POLICY "Users can create posts"
ON deeds
FOR INSERT
WITH CHECK (
  auth.uid() = user_id 
  AND is_validated = false
);
```

#### 3. Users can update their own posts (but not validation status)
```sql
CREATE POLICY "Users can update their own posts"
ON deeds
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (
  auth.uid() = user_id
  -- Prevent users from changing validation status
  AND (is_validated = OLD.is_validated)
);
```

#### 4. Backend service can update validation status
```sql
-- This policy allows a service role to update validation
-- You'll need to use service_role key in your backend
CREATE POLICY "Backend can update validation"
ON deeds
FOR UPDATE
USING (true) -- Service role bypasses RLS
WITH CHECK (true);
```

#### 5. Users can delete their own posts
```sql
CREATE POLICY "Users can delete their own posts"
ON deeds
FOR DELETE
USING (auth.uid() = user_id);
```

## Backend Validation Options

### Option 1: Supabase Edge Function (Recommended)

Create a Supabase Edge Function that triggers on post creation:

```typescript
// supabase/functions/validate-deed/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client with service role
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    const { deedId } = await req.json()

    // Get the deed
    const { data: deed, error: fetchError } = await supabaseClient
      .from('deeds')
      .select('*')
      .eq('id', deedId)
      .single()

    if (fetchError || !deed) {
      throw new Error('Deed not found')
    }

    // Skip if already validated
    if (deed.is_validated) {
      return new Response(
        JSON.stringify({ success: true, message: 'Already validated' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate content using your AI service
    const validationResult = await validateContent({
      text: deed.content,
      mediaUrls: deed.media_urls || [],
      mediaType: deed.media_type,
    })

    // Update deed with validation result
    const { error: updateError } = await supabaseClient
      .from('deeds')
      .update({
        is_validated: validationResult.isValid,
        validation_reason: validationResult.reason,
        validation_confidence: validationResult.confidence,
        validated_at: new Date().toISOString(),
      })
      .eq('id', deedId)

    if (updateError) {
      throw updateError
    }

    // If valid, award XP
    if (validationResult.isValid) {
      await awardXPForDeed(supabaseClient, deed.user_id)
    } else {
      // If invalid, add negative point
      await addNegativePoint(supabaseClient, deed.user_id, validationResult.reason)
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        isValid: validationResult.isValid 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

async function validateContent({ text, mediaUrls, mediaType }) {
  // Call your Groq API or validation service
  // Return: { isValid: boolean, reason: string, confidence: number }
  
  const response = await fetch('YOUR_VALIDATION_API_ENDPOINT', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text, mediaUrls, mediaType }),
  })
  
  return await response.json()
}

async function awardXPForDeed(supabaseClient, userId) {
  const { error } = await supabaseClient.rpc('increment_user_xp', {
    user_id: userId,
    xp_amount: 5, // AppConstants.xpPerDeedPost
  })
  
  if (error) {
    // Fallback to direct update
    const { data: user } = await supabaseClient
      .from('users')
      .select('xp')
      .eq('id', userId)
      .single()
    
    await supabaseClient
      .from('users')
      .update({ xp: (user.xp || 0) + 5 })
      .eq('id', userId)
  }
}

async function addNegativePoint(supabaseClient, userId, reason) {
  // Implement your moderation logic
  // Update user's negative points
}
```

### Option 2: Database Trigger + Webhook

Create a database trigger that calls a webhook:

```sql
-- Function to call webhook
CREATE OR REPLACE FUNCTION notify_deed_created()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://your-validation-service.com/validate',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := json_build_object(
      'deed_id', NEW.id,
      'content', NEW.content,
      'media_urls', NEW.media_urls,
      'media_type', NEW.media_type
    )::text
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger on insert
CREATE TRIGGER on_deed_created
AFTER INSERT ON deeds
FOR EACH ROW
WHEN (NEW.is_validated = false)
EXECUTE FUNCTION notify_deed_created();
```

### Option 3: External Service with Supabase Realtime

Use Supabase Realtime to listen for new posts:

```typescript
// External service
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

// Listen for new posts
supabase
  .channel('deeds')
  .on('postgres_changes', 
    { 
      event: 'INSERT', 
      schema: 'public', 
      table: 'deeds',
      filter: 'is_validated=eq.false'
    }, 
    async (payload) => {
      const deed = payload.new
      // Validate and update
      await validateAndUpdateDeed(deed)
    }
  )
  .subscribe()
```

## Database Functions

### Function to increment XP
```sql
CREATE OR REPLACE FUNCTION increment_user_xp(
  user_id UUID,
  xp_amount INTEGER
)
RETURNS void AS $$
BEGIN
  UPDATE users
  SET 
    xp = COALESCE(xp, 0) + xp_amount,
    level = calculate_level(COALESCE(xp, 0) + xp_amount),
    updated_at = NOW()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;
```

## Testing

1. Create a post from the app
2. Check Supabase dashboard - post should have `is_validated: false`
3. Backend should validate (Edge Function/webhook triggers)
4. Post should update to `is_validated: true` if valid
5. Post should appear in feed only after validation

## Security Notes

1. **Service Role Key**: Keep your service role key secure - never expose it to the frontend
2. **RLS Policies**: Ensure RLS is properly configured
3. **Validation API**: Secure your validation API endpoint
4. **Rate Limiting**: Implement rate limiting in your validation service

## Migration

If you have existing posts:
```sql
-- Validate existing posts (one-time)
UPDATE deeds
SET 
  is_validated = true,
  validation_reason = 'Migrated from old system',
  validation_confidence = 1.0
WHERE is_validated IS NULL OR is_validated = false;
```
