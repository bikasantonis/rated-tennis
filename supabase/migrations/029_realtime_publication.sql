-- Migration 029 — Realtime publication (live cross-device updates)
--
-- Problem: the supabase_realtime publication was empty (verified on DEV and on
-- a fresh local replay), so Postgres Changes never fired for any table. The
-- notificationsProvider `.stream()` only ever delivered its initial snapshot —
-- the bell badge did not react to new notifications or "mark all read" — and
-- an open app had no way to learn that the opponent had confirmed a match.
--
-- Fix: publish the four tables the app listens to (realtimeSyncProvider and
-- notificationsProvider). The client treats every event as a "something
-- changed" signal and refetches through PostgREST, so payloads are never
-- rendered. Realtime applies each subscriber's RLS SELECT policy to INSERT and
-- UPDATE events before delivering them:
--   profiles        public or own row          (003 profiles_select_public)
--   match_results   winner / loser / submitter (026 match_results_select)
--   match_requests  requester / recipient      (003 match_requests_select)
--   notifications   own rows                   (003 notifications_select_own)
--
-- Replica identity is deliberately left at DEFAULT. Realtime does not apply RLS
-- to DELETE events; with DEFAULT they carry only the primary key, so nothing
-- leaks. REPLICA IDENTITY FULL on match_requests would let a withdrawn
-- challenge reach the recipient instantly, but would also let any
-- authenticated user subscribe with someone else's recipient_id filter and
-- receive the full deleted row. A withdrawn challenge therefore disappears from
-- the recipient's inbox on the next refresh or reconnect instead.
--
-- Idempotent: each table is added only if it is not already a member, so this
-- is safe whatever state a project's publication was left in by the Dashboard.

DO $$
DECLARE
  t text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;

  FOREACH t IN ARRAY ARRAY['profiles', 'match_results', 'match_requests', 'notifications'] LOOP
    IF NOT EXISTS (
      SELECT 1
        FROM pg_publication_tables
       WHERE pubname    = 'supabase_realtime'
         AND schemaname = 'public'
         AND tablename  = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END;
$$;
