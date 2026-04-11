-- Migration 011 — Fix profiles RLS: add INSERT policy and ensure trigger ownership
--
-- Root cause: profiles has RLS enabled (migration 003) but no INSERT policy.
-- PostgreSQL blocks all INSERTs when RLS is on and no policy matches.
-- The handle_new_user SECURITY DEFINER trigger should bypass RLS if owned by
-- postgres (BYPASSRLS), but this makes the policy explicit as a safety net.

-- ── Ensure handle_new_user runs as postgres so it always bypasses RLS ─────────

ALTER FUNCTION public.handle_new_user() OWNER TO postgres;

-- ── Add missing INSERT policy on profiles ─────────────────────────────────────
-- Profile rows are ONLY ever created by the auth trigger (handle_new_user).
-- Clients cannot INSERT directly — they go through Supabase Auth which fires
-- the trigger. The policy is permissive (true) because auth.uid() is NULL at
-- the point the trigger fires (the JWT doesn't exist yet for the new user).

CREATE POLICY "profiles_insert_trigger"
  ON public.profiles
  FOR INSERT
  WITH CHECK (true);

-- ── Explicit GRANT as belt-and-suspenders ─────────────────────────────────────

GRANT INSERT ON public.profiles TO postgres;
GRANT INSERT ON public.profiles TO service_role;
