-- ============================================================
-- RATED — Migration 030: Questionnaire v3
-- ============================================================
-- Adds the tournament-activity block and play frequency, normalises
-- us_college_division from display strings to slugs, and introduces
-- profiles.questionnaire_version as the single "which questionnaire did this
-- player take" signal driving the retake prompt (ADR-18).
--
-- Backward compatible by construction: every new answer column is nullable and
-- questionnaire_version defaults to 0, so this migration can be applied while
-- the v2 app is still live (DATABASE.md §7 — DB before app).
--
-- New columns:  play_frequency, tournaments_last_3y, tournaments_per_year,
--               tournament_level, updated_at
-- Dropped:      nothing — v2 rows stay readable and renderable as they are.

-- ── 1. New answer columns ─────────────────────────────────────────────────────

alter table public.questionnaire_responses
  add column if not exists play_frequency       varchar(20),
  add column if not exists tournaments_last_3y  boolean,
  add column if not exists tournaments_per_year integer,
  add column if not exists tournament_level     varchar(20),
  add column if not exists updated_at           timestamptz;

alter table public.questionnaire_responses
  add constraint qr_play_frequency_check
    check (play_frequency is null or play_frequency in
      ('rarely','monthly','weekly','multiple_weekly')),

  add constraint qr_tournaments_per_year_check
    check (tournaments_per_year is null or
      (tournaments_per_year >= 1 and tournaments_per_year <= 100)),

  -- Ascending in standard of play; 'open' (open / national draws) is the top rung.
  add constraint qr_tournament_level_check
    check (tournament_level is null or tournament_level in
      ('amateur','intermediate','age_category','master','open')),

  -- The routed pair must be present exactly when the gate is true. Written as
  -- `is not true` so v2 rows (tournaments_last_3y is null) satisfy it untouched.
  add constraint qr_tournament_block_check
    check (tournaments_last_3y is not true
           or (tournaments_per_year is not null and tournament_level is not null));

-- Answers are immutable to clients (026), but seed-elo upserts them with the
-- service role on a retake, so the row genuinely does get updated.
create trigger trg_questionnaire_responses_updated_at
  before update on public.questionnaire_responses
  for each row execute function public.set_updated_at();

-- ── 2. us_college_division: display string → slug ─────────────────────────────
-- 021 added this column with no CHECK, so it stores the literal English label
-- the client rendered ('Division I'). That one value was simultaneously the UI
-- label, the stored value and the scoring key. Normalise, then constrain.
--
-- Note this step is not reversible in a useful way: an older seed-elo build
-- comparing `=== 'Division I'` would score every college player as non-D1.

update public.questionnaire_responses
   set us_college_division = case us_college_division
         when 'Division I'   then 'division_1'
         when 'Division II'  then 'division_2'
         when 'Division III' then 'division_3'
         when 'NAIA'         then 'naia'
         when 'NJCAA'        then 'njcaa'
         else us_college_division
       end
 where us_college_division is not null;

alter table public.questionnaire_responses
  add constraint qr_us_college_division_check
    check (us_college_division is null or us_college_division in
      ('division_1','division_2','division_3','naia','njcaa'));

-- ── 3. Questionnaire version on the profile ───────────────────────────────────
-- 0 = never taken, 2 = completed questionnaire v2 (retake due), 3 = current.
--
-- This lives on profiles rather than questionnaire_responses because the retake
-- prompt is decided from currentProfileProvider, which already selects from
-- profiles — the alternative would cost a second query on every home render.
-- No upper bound in the CHECK: bumping to v4 must not need a migration purely
-- to widen a constraint.

alter table public.profiles
  add column if not exists questionnaire_version smallint not null default 0;

update public.profiles
   set questionnaire_version = 2
 where questionnaire_done = true
   and questionnaire_version = 0;

alter table public.profiles
  add constraint profiles_questionnaire_version_check
    check (questionnaire_version >= 0);

comment on column public.profiles.questionnaire_version is
  'Questionnaire version this player last completed: 0 never, 2 = v2 (021), 3 = v3 (030). Lower than the app constant means a retake is due.';
