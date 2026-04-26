-- ============================================================
-- Migration 018: Profile enhancements
-- Adds peak_elo denormalised column, a trigger to maintain it,
-- a get_player_rank() RPC, and RLS policy updates for
-- tournament history and questionnaire public access.
-- ============================================================

-- ── 1. New column ───────────────────────────────────────────────────────────

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS peak_elo numeric(4,1);

-- ── 2. Backfill from existing elo_history rows ──────────────────────────────

UPDATE public.profiles p
  SET peak_elo = (
    SELECT MAX(elo_after)
    FROM public.elo_history
    WHERE player_id = p.id
  )
  WHERE p.peak_elo IS NULL;

-- ── 3. Trigger: keep peak_elo up to date on new elo_history inserts ─────────

CREATE OR REPLACE FUNCTION public.update_peak_elo()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
    SET peak_elo = GREATEST(COALESCE(peak_elo, 5.0), NEW.elo_after)
    WHERE id = NEW.player_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_peak_elo ON public.elo_history;
CREATE TRIGGER trg_update_peak_elo
  AFTER INSERT ON public.elo_history
  FOR EACH ROW EXECUTE FUNCTION public.update_peak_elo();

-- ── 4. RPC: single-player global rank ───────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_player_rank(p_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT (COUNT(*)::integer + 1)
  FROM profiles
  WHERE is_public = true
    AND deleted_at IS NULL
    AND (
      elo_rating > (SELECT elo_rating FROM profiles WHERE id = p_id)
      OR (
        elo_rating = 10.0
        AND (SELECT elo_rating FROM profiles WHERE id = p_id) = 10.0
        AND COALESCE(prestige_score, 0) >
            (SELECT COALESCE(prestige_score, 0) FROM profiles WHERE id = p_id)
      )
    );
$$;

GRANT EXECUTE ON FUNCTION public.get_player_rank(uuid) TO authenticated, anon;

-- ── 5. RLS: allow viewing tournament registrations for public profiles ───────

CREATE POLICY "tournament_reg_select_public_player"
  ON public.tournament_registrations FOR SELECT
  USING (
    player_id = auth.uid()
    OR is_organizer_or_admin()
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = player_id
        AND p.is_public = true
        AND p.deleted_at IS NULL
    )
  );

-- ── 6. RLS: allow reading questionnaire answers for public profiles ──────────

CREATE POLICY "questionnaire_select_public_profile"
  ON public.questionnaire_responses FOR SELECT
  USING (
    player_id = auth.uid()
    OR is_admin()
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = player_id
        AND p.is_public = true
        AND p.questionnaire_done = true
        AND p.deleted_at IS NULL
    )
  );
