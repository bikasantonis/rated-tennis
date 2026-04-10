-- ============================================================
-- RATED — Migration 006: ELO scale change
-- Changes elo_rating and seed_elo from integer [400,1200]
-- to numeric(4,1) [5.0, 10.0] (1 decimal place).
-- ============================================================

-- ── Drop trigger that depends on elo_rating before altering the column ────────

drop trigger if exists trg_profiles_sync_elo_tier on public.profiles;

-- ── profiles: change elo_rating column type and constraints ──────────────────

alter table public.profiles
  alter column elo_rating type numeric(4,1) using round(elo_rating::numeric, 1),
  alter column elo_rating set default 5.0;

alter table public.profiles
  drop constraint if exists profiles_elo_rating_check;

alter table public.profiles
  add constraint profiles_elo_rating_check
    check (elo_rating between 5.0 and 10.0);

-- Reset existing rows to minimum seed value
update public.profiles set elo_rating = 5.0;

-- ── questionnaire_responses: change seed_elo column type and constraints ─────

alter table public.questionnaire_responses
  alter column seed_elo type numeric(4,1) using round(seed_elo::numeric, 1);

alter table public.questionnaire_responses
  drop constraint if exists questionnaire_responses_seed_elo_check;

alter table public.questionnaire_responses
  add constraint questionnaire_responses_seed_elo_check
    check (seed_elo between 5.0 and 10.0);

-- ── Update sync_elo_tier function with new tier thresholds ───────────────────

create or replace function public.sync_elo_tier()
returns trigger
language plpgsql
as $$
begin
  new.elo_tier = case
    when new.elo_rating >= 9.5 then 'elite'
    when new.elo_rating >= 9.0 then 'platinum'
    when new.elo_rating >= 8.0 then 'gold'
    when new.elo_rating >= 7.0 then 'silver'
    when new.elo_rating >= 6.0 then 'bronze'
    else 'beginner'
  end;
  return new;
end;
$$;

-- ── Recreate the trigger ──────────────────────────────────────────────────────

create trigger trg_profiles_sync_elo_tier
  before insert or update of elo_rating on public.profiles
  for each row execute function public.sync_elo_tier();
