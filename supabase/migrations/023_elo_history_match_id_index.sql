-- Migration 023 — Add missing index on elo_history.match_id
--
-- apply_elo_changes() has an idempotency guard:
--   IF EXISTS (SELECT 1 FROM elo_history WHERE match_id = p_match_id)
-- Without an index this does a full table scan on every match confirmation.

CREATE INDEX IF NOT EXISTS idx_elo_history_match_id
  ON public.elo_history (match_id);
