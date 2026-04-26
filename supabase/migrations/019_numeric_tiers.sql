-- Migration 019 — Numeric tier system + delta bounds + friendly void
--
-- Changes:
--   1. Tier system: 6 named tiers → 11 numeric tiers at 0.5-point intervals
--      ('5.0', '5.5', '6.0', …, '9.5', '10.0')
--   2. Delta bounds: hard clamp [0.01, 0.20] applied to every match
--   3. Tournament elo_multiplier capped at 1.5 (max K = 0.225)
--   4. Friendly void: if tier diff > 1.5 steps, match is ELO-excluded
--      and both players are notified via the notifications table


-- ── 1. Drop old named-tier check constraint ───────────────────────────────────

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_elo_tier_check;


-- ── 2. New sync_elo_tier trigger — 0.5-point numeric bands ───────────────────

CREATE OR REPLACE FUNCTION public.sync_elo_tier()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  new.elo_tier = CASE
    WHEN new.elo_rating >= 10.0 THEN '10.0'
    WHEN new.elo_rating >= 9.5  THEN '9.5'
    WHEN new.elo_rating >= 9.0  THEN '9.0'
    WHEN new.elo_rating >= 8.5  THEN '8.5'
    WHEN new.elo_rating >= 8.0  THEN '8.0'
    WHEN new.elo_rating >= 7.5  THEN '7.5'
    WHEN new.elo_rating >= 7.0  THEN '7.0'
    WHEN new.elo_rating >= 6.5  THEN '6.5'
    WHEN new.elo_rating >= 6.0  THEN '6.0'
    WHEN new.elo_rating >= 5.5  THEN '5.5'
    ELSE '5.0'
  END;
  RETURN new;
END;
$$;

-- Trigger already exists from migration 004 — just recreate the function above.
-- The trigger definition (trg_profiles_sync_elo_tier) is unchanged.


-- ── 3. Backfill existing profiles ────────────────────────────────────────────

UPDATE public.profiles
  SET elo_tier = CASE
    WHEN elo_rating >= 10.0 THEN '10.0'
    WHEN elo_rating >= 9.5  THEN '9.5'
    WHEN elo_rating >= 9.0  THEN '9.0'
    WHEN elo_rating >= 8.5  THEN '8.5'
    WHEN elo_rating >= 8.0  THEN '8.0'
    WHEN elo_rating >= 7.5  THEN '7.5'
    WHEN elo_rating >= 7.0  THEN '7.0'
    WHEN elo_rating >= 6.5  THEN '6.5'
    WHEN elo_rating >= 6.0  THEN '6.0'
    WHEN elo_rating >= 5.5  THEN '5.5'
    ELSE '5.0'
  END;


-- ── 4. Add new check constraint ───────────────────────────────────────────────

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_elo_tier_check
  CHECK (elo_tier IN ('5.0','5.5','6.0','6.5','7.0','7.5','8.0','8.5','9.0','9.5','10.0'));


-- ── 5. Fix handle_new_user — initial tier '5.0' instead of 'beginner' ─────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_display_name text;
BEGIN
  v_display_name := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'display_name'), ''),
    NULLIF(TRIM(SPLIT_PART(NEW.email, '@', 1)), ''),
    'Player'
  );

  IF char_length(v_display_name) < 2 THEN
    v_display_name := v_display_name || '_';
  END IF;

  INSERT INTO public.profiles (id, display_name, elo_rating, elo_tier, role)
  VALUES (
    NEW.id,
    v_display_name,
    5.0,
    '5.0',
    'player'
  );

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_new_user() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;


-- ── 6. Add elo_excluded column to match_results ───────────────────────────────
-- Friendly matches where the tier gap exceeds 1.5 are marked excluded.
-- apply_elo_changes skips ELO updates for these matches.

ALTER TABLE public.match_results
  ADD COLUMN IF NOT EXISTS elo_excluded boolean NOT NULL DEFAULT false;


-- ── 7. Cap existing tournament multipliers at 1.5, add constraint ─────────────

UPDATE public.tournaments
  SET elo_multiplier = 1.5
  WHERE elo_multiplier > 1.5;

ALTER TABLE public.tournaments
  DROP CONSTRAINT IF EXISTS tournaments_elo_multiplier_check;

ALTER TABLE public.tournaments
  ADD CONSTRAINT tournaments_elo_multiplier_check
  CHECK (elo_multiplier BETWEEN 1.0 AND 1.5);


-- ── 8. Helper: notify both players that a match was ELO-excluded ──────────────

CREATE OR REPLACE FUNCTION public.notify_match_excluded(
  p_winner_id uuid,
  p_loser_id  uuid,
  p_match_id  uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO notifications (recipient_id, type, title, body, reference_id, reference_type)
  VALUES
    (
      p_winner_id,
      'match_elo_excluded',
      'Match not rated',
      'This friendly match did not affect ratings — the ranking gap between players exceeds 1.5 tiers.',
      p_match_id,
      'match_result'
    ),
    (
      p_loser_id,
      'match_elo_excluded',
      'Match not rated',
      'This friendly match did not affect ratings — the ranking gap between players exceeds 1.5 tiers.',
      p_match_id,
      'match_result'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.notify_match_excluded(uuid, uuid, uuid)
  TO authenticated, anon;


-- ── 9. Rewrite apply_elo_changes ──────────────────────────────────────────────
--
-- New rules vs migration 014:
--   a. Friendly void: skip ELO if |tier_winner - tier_loser| > 1.5
--      (tier computed as floor(elo_rating / 0.5) * 0.5)
--   b. K-factor: tournament cap at 1.5× (LEAST(multiplier, 1.5))
--   c. Delta clamp: GREATEST(0.01, LEAST(0.20, raw_delta))
--
-- All other logic (prestige, RATED handling) is preserved from migration 014.

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
  v_winner_tier_val numeric(4,1);
  v_loser_tier_val  numeric(4,1);
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

  -- Also skip if the match is already marked as excluded (e.g. re-trigger).
  SELECT * INTO STRICT v_match FROM match_results WHERE id = p_match_id;
  IF v_match.elo_excluded THEN
    RETURN;
  END IF;

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

  -- ── Friendly void check ───────────────────────────────────────────────────────
  -- Tier floor = floor(elo_rating / 0.5) * 0.5
  -- Example: 8.9900 → floor(8.99/0.5)*0.5 = floor(17.98)*0.5 = 17*0.5 = 8.5
  -- Example: 7.0100 → floor(7.01/0.5)*0.5 = floor(14.02)*0.5 = 14*0.5 = 7.0
  -- Diff of 2.0 > 1.5 → void; diff of 1.5 exactly → allowed (boundary is strict >)
  IF v_match.match_type != 'tournament'
     AND v_match.tournament_id IS NULL THEN

    v_winner_tier_val := floor(v_winner_elo / 0.5) * 0.5;
    v_loser_tier_val  := floor(v_loser_elo  / 0.5) * 0.5;

    IF abs(v_winner_tier_val - v_loser_tier_val) > 1.5 THEN
      -- Mark the match as ELO-excluded and notify both players.
      UPDATE match_results SET elo_excluded = true WHERE id = p_match_id;
      PERFORM notify_match_excluded(v_match.winner_id, v_match.loser_id, p_match_id);
      RETURN;
    END IF;
  END IF;

  -- ── K-factor (tournament max capped at 1.5×) ─────────────────────────────────
  IF v_match.match_type = 'tournament' AND v_match.tournament_id IS NOT NULL THEN
    SELECT 0.15 * LEAST(t.elo_multiplier, 1.5) INTO v_k
      FROM tournaments t WHERE t.id = v_match.tournament_id;
  ELSE
    v_k := 0.15;
  END IF;

  -- ── Effective ratings for the ELO formula ────────────────────────────────────
  -- RATED vs RATED: use (10.0 + prestige) so differences remain meaningful.
  -- Mixed:          RATED player appears as exactly 10.0 to the non-RATED side.
  IF v_winner_rated AND v_loser_rated THEN
    v_eff_winner := 10.0 + v_winner_prestige;
    v_eff_loser  := 10.0 + v_loser_prestige;
  ELSE
    v_eff_winner := v_winner_elo;
    v_eff_loser  := v_loser_elo;
  END IF;

  -- ── Delta with hard clamp [0.01, 0.20] ───────────────────────────────────────
  -- Raw: K × (1 − E_winner)
  -- Floor 0.01 prevents chip-away micro-gains (favourite crushing a much weaker
  --   opponent in tournament still awards at least 0.01).
  -- Ceiling 0.20 caps extreme upset swings in high-stakes tournaments.
  v_e_winner := 1.0 / (1.0 + power(10.0::numeric, (v_eff_loser - v_eff_winner) / v_d));
  v_delta    := GREATEST(0.01, LEAST(0.20, v_k * (1.0 - v_e_winner)));

  -- ── Apply to winner ───────────────────────────────────────────────────────────
  IF v_winner_rated THEN
    UPDATE profiles
      SET prestige_score = COALESCE(prestige_score, 0) + v_delta
      WHERE id = v_match.winner_id;
    v_new_winner_elo := 10.0;
  ELSE
    v_new_winner_elo := GREATEST(5.0, LEAST(10.0, v_winner_elo + v_delta));
    UPDATE profiles SET elo_rating = v_new_winner_elo WHERE id = v_match.winner_id;
    IF v_new_winner_elo = 10.0 THEN
      UPDATE profiles
        SET prestige_score = 0
        WHERE id = v_match.winner_id AND prestige_score IS NULL;
    END IF;
  END IF;

  -- ── Apply to loser ────────────────────────────────────────────────────────────
  IF v_loser_rated THEN
    UPDATE profiles
      SET prestige_score = COALESCE(prestige_score, 0) - v_delta
      WHERE id = v_match.loser_id;
    v_new_loser_elo := 10.0;
  ELSE
    v_new_loser_elo := GREATEST(5.0, LEAST(10.0, v_loser_elo - v_delta));
    UPDATE profiles SET elo_rating = v_new_loser_elo WHERE id = v_match.loser_id;
  END IF;

  -- ── ELO history ledger ────────────────────────────────────────────────────────
  INSERT INTO elo_history (player_id, match_id, elo_before, elo_after, delta, event_type)
  VALUES
    (v_match.winner_id, p_match_id, v_winner_elo, v_new_winner_elo,  v_delta,  'match'),
    (v_match.loser_id,  p_match_id, v_loser_elo,  v_new_loser_elo,  -v_delta, 'match');
END;
$$;
