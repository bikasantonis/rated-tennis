-- Migration 022 — Restore Google avatar extraction in handle_new_user
--
-- Migration 019_numeric_tiers correctly updated the tier from 'beginner' → '5.0'
-- but dropped the avatar_url extraction that was in the Google-auth migration.
-- This migration merges both: robust display_name + OAuth avatar + correct tier.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_display_name text;
  v_avatar_url   text;
BEGIN
  v_display_name := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'display_name'), ''),
    NULLIF(TRIM(SPLIT_PART(NEW.email, '@', 1)), ''),
    'Player'
  );

  IF char_length(v_display_name) < 2 THEN
    v_display_name := v_display_name || '_';
  END IF;

  -- Google OAuth provides the profile photo under 'avatar_url' (Supabase ≥2)
  -- or 'picture' (older Supabase / raw Google token).
  v_avatar_url := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'avatar_url'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data->>'picture'), '')
  );

  INSERT INTO public.profiles (id, display_name, avatar_url, elo_rating, elo_tier, role)
  VALUES (
    NEW.id,
    v_display_name,
    v_avatar_url,
    5.0,
    '5.0',
    'player'
  );

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_new_user() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;
