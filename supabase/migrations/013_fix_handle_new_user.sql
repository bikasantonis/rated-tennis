-- Migration 013 — Robustly fix handle_new_user trigger function
--
-- Root cause candidates:
--   1. display_name check constraint (char_length >= 2) can fail if the email
--      prefix is a single character (e.g. a@example.com) and raw_user_meta_data
--      has no 'display_name' key.
--   2. supabase_auth_admin may not have EXECUTE on the function, so the trigger
--      fires in a context where it is denied (even if SECURITY DEFINER applies).
--   3. search_path = public can allow search-path injection; Supabase recommends
--      an empty search_path with fully-qualified names.
--
-- Fix: recreate with set search_path = '', robust COALESCE for display_name,
--      and explicit EXECUTE grant to supabase_auth_admin.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_display_name text;
BEGIN
  -- Prefer the display_name the client passed in user metadata.
  -- Fall back to the email prefix, then to 'Player' as a last resort so the
  -- char_length >= 2 constraint on profiles.display_name can never be violated.
  v_display_name := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'display_name'), ''),
    NULLIF(TRIM(SPLIT_PART(NEW.email, '@', 1)), ''),
    'Player'
  );

  -- Guarantee the constraint is always satisfied
  IF char_length(v_display_name) < 2 THEN
    v_display_name := v_display_name || '_';
  END IF;

  INSERT INTO public.profiles (id, display_name, elo_rating, elo_tier, role)
  VALUES (
    NEW.id,
    v_display_name,
    5.0,
    'beginner',
    'player'
  );

  RETURN NEW;
END;
$$;

-- Ensure ownership is postgres (SECURITY DEFINER runs as owner)
ALTER FUNCTION public.handle_new_user() OWNER TO postgres;

-- Grant EXECUTE to the role Supabase Auth uses to write auth.users rows.
-- Without this the trigger call can be denied in some Supabase Cloud setups.
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;
