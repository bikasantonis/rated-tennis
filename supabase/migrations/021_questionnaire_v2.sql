-- Migration 021 — Questionnaire v2
-- Replaces the original 5-field questionnaire with a new sport-history questionnaire
-- that drives the revised seed-ELO algorithm.
--
-- Old columns removed:  playing_frequency, self_assessed_level, preferred_surface, has_competed
-- New columns added:    date_of_birth, greek_experience, international_experience,
--                       junior_career_high_ranking, received_atp_wta_point,
--                       us_college_division, other_sport
-- years_playing is kept (check constraint widened to 80).

-- ── 1. Drop obsolete columns ──────────────────────────────────────────────────
ALTER TABLE public.questionnaire_responses
  DROP COLUMN IF EXISTS playing_frequency,
  DROP COLUMN IF EXISTS self_assessed_level,
  DROP COLUMN IF EXISTS preferred_surface,
  DROP COLUMN IF EXISTS has_competed;

-- ── 2. Widen years_playing constraint ─────────────────────────────────────────
ALTER TABLE public.questionnaire_responses
  DROP CONSTRAINT IF EXISTS questionnaire_responses_years_playing_check;

ALTER TABLE public.questionnaire_responses
  ADD CONSTRAINT questionnaire_responses_years_playing_check
    CHECK (years_playing >= 0 AND years_playing <= 80);

-- ── 3. Add new columns (nullable so existing rows are unaffected) ─────────────
ALTER TABLE public.questionnaire_responses
  ADD COLUMN IF NOT EXISTS date_of_birth              date,
  ADD COLUMN IF NOT EXISTS greek_experience           varchar(20),
  ADD COLUMN IF NOT EXISTS international_experience   varchar(25),
  ADD COLUMN IF NOT EXISTS junior_career_high_ranking integer,
  ADD COLUMN IF NOT EXISTS received_atp_wta_point     boolean,
  ADD COLUMN IF NOT EXISTS us_college_division        varchar(30),
  ADD COLUMN IF NOT EXISTS other_sport                varchar(20);

-- ── 4. Check constraints ───────────────────────────────────────────────────────
ALTER TABLE public.questionnaire_responses
  ADD CONSTRAINT qr_greek_experience_check
    CHECK (greek_experience IS NULL OR greek_experience IN
      ('recreational','national_u200','national_20_200','national_top20')),
  ADD CONSTRAINT qr_intl_experience_check
    CHECK (international_experience IS NULL OR international_experience IN
      ('none','recreational_intl','junior_intl','professional_adult','us_college')),
  ADD CONSTRAINT qr_junior_ranking_check
    CHECK (junior_career_high_ranking IS NULL OR junior_career_high_ranking > 0),
  ADD CONSTRAINT qr_other_sport_check
    CHECK (other_sport IS NULL OR other_sport IN
      ('racket_sports','other_sports','none'));
