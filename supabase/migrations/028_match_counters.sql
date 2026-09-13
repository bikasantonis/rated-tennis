-- Migration 028 — Match counters (profiles.matches_played / matches_won)
--
-- Problem: both columns were declared in 001_initial_schema.sql and only ever
-- read (currentProfileProvider, playerProfileProvider, get_leaderboard_page,
-- EloScoreCard, ProfileScreen). Nothing ever wrote them, so every profile
-- reported "0 Played · 0 Won · — Win %" no matter how many matches were played.
--
-- Fix: a trigger on match_results keyed on the *counted* status set, plus a
-- one-shot backfill.
--
-- Why a trigger rather than apply_elo_changes: that function early-returns for
-- ELO-excluded matches and when elo_history rows already exist, so it cannot be
-- the counter's home. A status trigger covers all four confirmation paths
-- uniformly:
--   1. Opponent confirms      — functions/elo-recalculate/index.ts
--   2. 48 h auto-confirm cron — 024_notifications_dedup_and_cron_guard.sql
--   3. Admin approves dispute — DisputeActions.approveDispute
--   4. Admin overrides        — DisputeActions.overrideDispute
--
-- A "counted" match is status IN ('confirmed','overridden'): every match the
-- user can see in their feed counts as Played, including tournament matches and
-- ELO-excluded friendlies, so Played always agrees with the match history.


-- ── 1. Trigger function ───────────────────────────────────────────────────────
--
-- SECURITY DEFINER: profiles RLS only allows a user to update their own row,
-- and every confirmation writes the opponent's counters too.

CREATE OR REPLACE FUNCTION public.sync_match_counters()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_was_counted boolean := false;
  v_is_counted  boolean;
  -- Participants whose counters must be reversed (old pair) / applied (new pair).
  -- Left NULL when that side contributes nothing, which drops it from the
  -- adjustment set below. OLD is only ever read on UPDATE — referencing it on
  -- INSERT raises "record old is not assigned yet".
  v_old_winner  uuid;
  v_old_loser   uuid;
  v_new_winner  uuid;
  v_new_loser   uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    v_was_counted := OLD.status IN ('confirmed','overridden');
  END IF;
  v_is_counted := NEW.status IN ('confirmed','overridden');

  -- No-op when the counted state and both participants are unchanged. This is
  -- what makes the trigger safe against the set_updated_at bump and against the
  -- repeated `UPDATE ... SET status = 'confirmed'` in the edge/cron paths.
  IF TG_OP = 'UPDATE'
     AND v_was_counted = v_is_counted
     AND OLD.winner_id IS NOT DISTINCT FROM NEW.winner_id
     AND OLD.loser_id  IS NOT DISTINCT FROM NEW.loser_id THEN
    RETURN NULL;
  END IF;

  IF v_was_counted THEN
    v_old_winner := OLD.winner_id;
    v_old_loser  := OLD.loser_id;
  END IF;

  IF v_is_counted THEN
    v_new_winner := NEW.winner_id;
    v_new_loser  := NEW.loser_id;
  END IF;

  IF v_old_winner IS NULL AND v_old_loser IS NULL
     AND v_new_winner IS NULL AND v_new_loser IS NULL THEN
    RETURN NULL;
  END IF;

  -- Lock the affected profile rows in a deterministic (id) order. apply_elo_changes
  -- takes SELECT ... FOR UPDATE on winner then loser; locking by id here means two
  -- concurrent counter updates on the same pair can never deadlock each other.
  PERFORM 1
    FROM public.profiles
   WHERE id IN (v_old_winner, v_old_loser, v_new_winner, v_new_loser)
   ORDER BY id
     FOR UPDATE;

  -- One UPDATE for both players. A player present in the old *and* new pair on
  -- the same side nets to zero and is filtered out by the HAVING, so a plain
  -- status flip with unchanged participants can never double-count.
  -- GREATEST(0, …) respects the `check (>= 0)` constraints on both columns.
  WITH adjustments AS (
    SELECT player_id,
           sum(d_played) AS d_played,
           sum(d_won)    AS d_won
      FROM (
        SELECT v_old_winner AS player_id, -1 AS d_played, -1 AS d_won
         WHERE v_old_winner IS NOT NULL
        UNION ALL
        SELECT v_old_loser, -1, 0
         WHERE v_old_loser IS NOT NULL
        UNION ALL
        SELECT v_new_winner, 1, 1
         WHERE v_new_winner IS NOT NULL
        UNION ALL
        SELECT v_new_loser, 1, 0
         WHERE v_new_loser IS NOT NULL
      ) contributions
     GROUP BY player_id
    HAVING sum(d_played) <> 0 OR sum(d_won) <> 0
  )
  UPDATE public.profiles p
     SET matches_played = GREATEST(0, p.matches_played + a.d_played),
         matches_won    = GREATEST(0, p.matches_won    + a.d_won)
    FROM adjustments a
   WHERE p.id = a.player_id;

  RETURN NULL; -- AFTER ... FOR EACH ROW — return value is ignored
END;
$$;


-- ── 2. Trigger ────────────────────────────────────────────────────────────────
--
-- INSERT is covered defensively: no current path inserts an already-counted row
-- (submitMatch always lands on the 'pending' default, and tournament brackets
-- live in tournament_bracket_matches), but a future seeding path might.
--
-- This does not disturb the other profiles triggers: trg_profiles_updated_at is
-- BEFORE UPDATE (the counter write is a legitimate update), and
-- trg_profiles_sync_elo_tier is BEFORE INSERT OR UPDATE **OF elo_rating**, so it
-- never fires for a counter-only write.

DROP TRIGGER IF EXISTS trg_match_counters ON public.match_results;

CREATE TRIGGER trg_match_counters
  AFTER INSERT OR UPDATE ON public.match_results
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_match_counters();


-- ── 3. Backfill ───────────────────────────────────────────────────────────────
--
-- Full recompute rather than an increment, so this statement is safe to re-run.
-- The WHERE clause skips already-correct rows so the backfill does not bump
-- updated_at across the whole table.

WITH tally AS (
  SELECT player_id,
         count(*)                          AS played,
         count(*) FILTER (WHERE is_winner) AS won
    FROM (
      SELECT winner_id AS player_id, true AS is_winner
        FROM public.match_results
       WHERE status IN ('confirmed','overridden')
      UNION ALL
      SELECT loser_id, false
        FROM public.match_results
       WHERE status IN ('confirmed','overridden')
    ) contributions
   GROUP BY player_id
),
target AS (
  SELECT p.id,
         COALESCE(t.played, 0)::integer AS played,
         COALESCE(t.won,    0)::integer AS won
    FROM public.profiles p
    LEFT JOIN tally t ON t.player_id = p.id
   WHERE p.matches_played <> COALESCE(t.played, 0)
      OR p.matches_won    <> COALESCE(t.won,    0)
)
UPDATE public.profiles p
   SET matches_played = tg.played,
       matches_won    = tg.won
  FROM target tg
 WHERE p.id = tg.id;
