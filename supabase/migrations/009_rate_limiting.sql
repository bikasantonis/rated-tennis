-- Migration 009 — Rate limiting (PRD §6.1)
-- 1. Match submissions: max 20 per user per rolling hour (BEFORE INSERT trigger).
-- 2. Auth rate limits are configured in supabase/config.toml (local) and the
--    Supabase Dashboard → Auth → Rate Limits (production).

-- ── Match submission rate limit ───────────────────────────────────────────────

CREATE OR REPLACE FUNCTION check_match_submission_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*)
    INTO v_count
    FROM match_results
   WHERE submitter_id = NEW.submitter_id
     AND created_at  >= NOW() - INTERVAL '1 hour';

  IF v_count >= 20 THEN
    RAISE EXCEPTION
      'rate_limit_exceeded: max 20 match submissions per hour (current: %)', v_count
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

-- Add created_at if not already present (guard for local dev reset)
ALTER TABLE match_results
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

DROP TRIGGER IF EXISTS trg_match_submission_rate_limit ON match_results;

CREATE TRIGGER trg_match_submission_rate_limit
  BEFORE INSERT ON match_results
  FOR EACH ROW
  EXECUTE FUNCTION check_match_submission_rate_limit();

COMMENT ON FUNCTION check_match_submission_rate_limit() IS
  'PRD §6.1 — rejects INSERT when the submitter has already submitted 20 matches in the past 60 minutes.';
