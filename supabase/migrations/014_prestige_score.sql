-- Migration 014 — RATED prestige score
--
-- Players whose elo_rating reaches 10.0 become "RATED". Their visible rating
-- is capped at 10.0 forever, but a hidden prestige_score accumulates so that
-- RATED players can still be ranked among themselves.
--
-- Rules enforced by apply_elo_changes:
--   • Non-RATED vs Non-RATED  → normal ELO on elo_rating
--   • RATED vs Non-RATED      → non-RATED uses 10.0 as opponent rating (no
--                               inflation from high prestige); RATED player's
--                               prestige changes, elo_rating stays at 10.0
--   • RATED vs RATED          → compare via (10.0 + prestige) so the formula
--                               remains meaningful; both elo_ratings stay at 10.0
--
-- prestige_score is intentionally excluded from all public-facing API responses.
-- Clients see only elo_rating (capped at 10.0) and a pre-computed global_rank
-- column returned by get_leaderboard_page().

-- ── Add prestige_score column ─────────────────────────────────────────────────

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS prestige_score NUMERIC(10,4) DEFAULT NULL;

-- Initialise any existing players already sitting at 10.0
UPDATE public.profiles
  SET prestige_score = 0
  WHERE elo_rating = 10.0 AND prestige_score IS NULL;

-- ── get_rated_rank: global rank of a RATED player ─────────────────────────────
-- Returns the number of RATED players with a higher prestige_score + 1.
-- Returns NULL when the player is not RATED (< 10.0).

CREATE OR REPLACE FUNCTION public.get_rated_rank(p_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    CASE
      WHEN (SELECT elo_rating FROM profiles WHERE id = p_id) < 10.0
        THEN NULL
      ELSE (
        SELECT (COUNT(*)::integer + 1)
        FROM profiles
        WHERE elo_rating = 10.0
          AND deleted_at IS NULL
          AND COALESCE(prestige_score, 0) >
              (SELECT COALESCE(prestige_score, 0) FROM profiles WHERE id = p_id)
      )
    END;
$$;

GRANT EXECUTE ON FUNCTION public.get_rated_rank(uuid) TO authenticated, anon;

-- ── get_leaderboard_page: ordered page with pre-computed global_rank ──────────
-- RATED players (elo_rating = 10.0) always appear at the top, sorted among
-- themselves by prestige_score DESC. Non-RATED players follow, sorted by
-- elo_rating DESC. The prestige_score itself is never returned to clients.

CREATE OR REPLACE FUNCTION public.get_leaderboard_page(
  p_page      integer DEFAULT 0,
  p_page_size integer DEFAULT 50,
  p_club_id   uuid    DEFAULT NULL
)
RETURNS TABLE (
  id             uuid,
  display_name   varchar,
  avatar_url     text,
  elo_rating     numeric,
  elo_tier       varchar,
  matches_played integer,
  matches_won    integer,
  club_id        uuid,
  global_rank    integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH ranked AS (
    SELECT
      p.id,
      p.display_name,
      p.avatar_url,
      p.elo_rating,
      p.elo_tier::varchar,
      p.matches_played,
      p.matches_won,
      p.club_id,
      ROW_NUMBER() OVER (
        ORDER BY
          -- RATED players first
          CASE WHEN p.elo_rating = 10.0 THEN 0 ELSE 1 END ASC,
          -- Among RATED: highest prestige first; NULLs treated as 0
          CASE WHEN p.elo_rating = 10.0
               THEN COALESCE(p.prestige_score, 0)
               ELSE NULL END DESC NULLS LAST,
          -- Non-RATED: highest elo_rating first
          p.elo_rating DESC
      )::integer AS global_rank
    FROM profiles p
    WHERE p.is_public   = true
      AND p.deleted_at  IS NULL
      AND (p_club_id IS NULL OR p.club_id = p_club_id)
  )
  SELECT * FROM ranked
  ORDER BY global_rank
  LIMIT  p_page_size
  OFFSET p_page * p_page_size;
$$;

GRANT EXECUTE ON FUNCTION public.get_leaderboard_page(integer, integer, uuid)
  TO authenticated, anon;

-- ── apply_elo_changes: rewrite to support prestige ────────────────────────────

CREATE OR REPLACE FUNCTION public.apply_elo_changes(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match           match_results%rowtype;
  v_winner_elo      numeric(8,4);
  v_loser_elo       numeric(8,4);
  v_winner_prestige numeric(10,4);
  v_loser_prestige  numeric(10,4);
  v_winner_rated    boolean;
  v_loser_rated     boolean;
  v_k               numeric(8,4);
  v_d     CONSTANT  numeric(8,4) := 1.67;
  v_eff_winner      numeric(12,4);
  v_eff_loser       numeric(12,4);
  v_e_winner        numeric(14,8);
  v_delta           numeric(8,4);
  v_new_winner_elo  numeric(8,4);
  v_new_loser_elo   numeric(8,4);
BEGIN
  -- ── Idempotency guard ────────────────────────────────────────────────────────
  IF EXISTS (SELECT 1 FROM elo_history WHERE match_id = p_match_id) THEN
    RETURN;
  END IF;

  SELECT * INTO STRICT v_match FROM match_results WHERE id = p_match_id;

  -- ── Lock rows and read current state ─────────────────────────────────────────
  SELECT elo_rating,
         COALESCE(prestige_score, 0),
         (elo_rating = 10.0)
    INTO v_winner_elo, v_winner_prestige, v_winner_rated
    FROM profiles WHERE id = v_match.winner_id FOR UPDATE;

  SELECT elo_rating,
         COALESCE(prestige_score, 0),
         (elo_rating = 10.0)
    INTO v_loser_elo, v_loser_prestige, v_loser_rated
    FROM profiles WHERE id = v_match.loser_id FOR UPDATE;

  -- ── K-factor ─────────────────────────────────────────────────────────────────
  IF v_match.match_type = 'tournament' AND v_match.tournament_id IS NOT NULL THEN
    SELECT 0.15 * t.elo_multiplier INTO v_k
      FROM tournaments t WHERE t.id = v_match.tournament_id;
  ELSE
    v_k := 0.15;
  END IF;

  -- ── Effective ratings for the ELO formula ────────────────────────────────────
  -- RATED vs RATED: use (10.0 + prestige) so differences remain meaningful.
  -- Mixed:          RATED player appears as exactly 10.0 to the non-RATED side,
  --                 preventing extreme swings from an inflated prestige value.
  IF v_winner_rated AND v_loser_rated THEN
    v_eff_winner := 10.0 + v_winner_prestige;
    v_eff_loser  := 10.0 + v_loser_prestige;
  ELSE
    v_eff_winner := v_winner_elo;   -- already 10.0 when rated
    v_eff_loser  := v_loser_elo;    -- already 10.0 when rated
  END IF;

  -- ── Delta ─────────────────────────────────────────────────────────────────────
  v_e_winner := 1.0 / (1.0 + power(10.0::numeric, (v_eff_loser - v_eff_winner) / v_d));
  v_delta    := v_k * (1.0 - v_e_winner);

  -- ── Apply to winner ───────────────────────────────────────────────────────────
  IF v_winner_rated THEN
    -- RATED winner: prestige grows, visible elo stays at 10.0
    UPDATE profiles
      SET prestige_score = COALESCE(prestige_score, 0) + v_delta
      WHERE id = v_match.winner_id;
    v_new_winner_elo := 10.0;
  ELSE
    v_new_winner_elo := GREATEST(5.0, LEAST(10.0, v_winner_elo + v_delta));
    UPDATE profiles SET elo_rating = v_new_winner_elo WHERE id = v_match.winner_id;
    -- First time reaching 10.0: initialise prestige
    IF v_new_winner_elo = 10.0 THEN
      UPDATE profiles
        SET prestige_score = 0
        WHERE id = v_match.winner_id AND prestige_score IS NULL;
    END IF;
  END IF;

  -- ── Apply to loser ────────────────────────────────────────────────────────────
  IF v_loser_rated THEN
    -- RATED loser: prestige shrinks (can become negative; rank ordering stays valid)
    UPDATE profiles
      SET prestige_score = COALESCE(prestige_score, 0) - v_delta
      WHERE id = v_match.loser_id;
    v_new_loser_elo := 10.0;
  ELSE
    v_new_loser_elo := GREATEST(5.0, LEAST(10.0, v_loser_elo - v_delta));
    UPDATE profiles SET elo_rating = v_new_loser_elo WHERE id = v_match.loser_id;
  END IF;

  -- ── elo_history ledger ────────────────────────────────────────────────────────
  -- Records the visible elo_rating (10.0 for RATED players) — delta shows the
  -- actual prestige change for RATED-vs-RATED matches.
  INSERT INTO elo_history (player_id, match_id, elo_before, elo_after, delta, event_type)
  VALUES
    (v_match.winner_id, p_match_id, v_winner_elo, v_new_winner_elo,  v_delta,  'match'),
    (v_match.loser_id,  p_match_id, v_loser_elo,  v_new_loser_elo,  -v_delta, 'match');
END;
$$;
