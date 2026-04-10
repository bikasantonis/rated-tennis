-- ============================================================
-- RATED — Migration 007: Widen ELO precision, add
--         apply_elo_changes function, pg_cron jobs.
--
-- ELO is stored at full numeric(8,4) precision internally.
-- Clients display round(elo_rating, 1) — the "hidden" sub-decimal
-- accumulates until it crosses the 0.05 rounding threshold.
-- ============================================================

-- ── Drop tier trigger before altering elo_rating again ───────────────────────

drop trigger if exists trg_profiles_sync_elo_tier on public.profiles;

-- ── profiles: widen elo_rating to numeric(8,4) ───────────────────────────────

alter table public.profiles
  alter column elo_rating type numeric(8,4) using elo_rating::numeric,
  alter column elo_rating set default 5.0000;

alter table public.profiles
  drop constraint if exists profiles_elo_rating_check;

alter table public.profiles
  add constraint profiles_elo_rating_check
    check (elo_rating between 5.0 and 10.0);

-- ── questionnaire_responses: widen seed_elo to numeric(8,4) ──────────────────

alter table public.questionnaire_responses
  alter column seed_elo type numeric(8,4) using seed_elo::numeric;

alter table public.questionnaire_responses
  drop constraint if exists questionnaire_responses_seed_elo_check;

alter table public.questionnaire_responses
  add constraint questionnaire_responses_seed_elo_check
    check (seed_elo between 5.0 and 10.0);

-- ── elo_history: widen all ELO columns to numeric(8,4) ───────────────────────

alter table public.elo_history
  alter column elo_before type numeric(8,4) using elo_before::numeric,
  alter column elo_after  type numeric(8,4) using elo_after::numeric,
  alter column delta      type numeric(8,4) using delta::numeric;

-- ── tournaments: widen elo_min/elo_max to numeric(8,4) ───────────────────────

alter table public.tournaments
  alter column elo_min type numeric(8,4) using elo_min::numeric,
  alter column elo_max type numeric(8,4) using elo_max::numeric;

alter table public.tournaments
  drop constraint if exists tournaments_elo_min_check,
  drop constraint if exists tournaments_elo_max_check;

alter table public.tournaments
  add constraint tournaments_elo_min_check check (elo_min >= 5.0),
  add constraint tournaments_elo_max_check check (elo_max >= elo_min);

-- ── Recreate sync_elo_tier trigger (unchanged thresholds) ────────────────────

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

create trigger trg_profiles_sync_elo_tier
  before insert or update of elo_rating on public.profiles
  for each row execute function public.sync_elo_tier();

-- ── apply_elo_changes: core ELO recalculation ────────────────────────────────
-- Scale: 5.0–10.0, K=0.15 (friendly) or K=0.15*elo_multiplier (tournament)
-- D=1.67 (proportional to standard 400/1200-range divisor scaled to 5-unit range)
-- No minimum delta: changes accumulate at full precision; display layer rounds.
-- Idempotent: no-ops if elo_history rows already exist for this match.

create or replace function public.apply_elo_changes(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match       match_results%rowtype;
  v_winner_elo  numeric(8,4);
  v_loser_elo   numeric(8,4);
  v_k           numeric(8,4);
  v_d constant  numeric(8,4) := 1.67;
  v_e_winner    numeric(14,8);
  v_delta       numeric(8,4);
  v_new_winner  numeric(8,4);
  v_new_loser   numeric(8,4);
begin
  -- Idempotency guard
  if exists (select 1 from elo_history where match_id = p_match_id) then
    return;
  end if;

  select * into strict v_match from match_results where id = p_match_id;

  -- Lock both profile rows to prevent concurrent rating updates
  select elo_rating into v_winner_elo
    from profiles where id = v_match.winner_id for update;
  select elo_rating into v_loser_elo
    from profiles where id = v_match.loser_id for update;

  -- K-factor
  if v_match.match_type = 'tournament' and v_match.tournament_id is not null then
    select 0.15 * t.elo_multiplier into v_k
      from tournaments t where t.id = v_match.tournament_id;
  else
    v_k := 0.15;
  end if;

  -- Expected score for winner: 1 / (1 + 10^((loser_elo - winner_elo) / D))
  v_e_winner := 1.0 / (1.0 + power(10.0::numeric, (v_loser_elo - v_winner_elo) / v_d));

  -- Raw delta — no rounding, no minimum; display layer shows round(elo, 1)
  v_delta := v_k * (1.0 - v_e_winner);

  -- New ratings clamped to [5.0, 10.0]
  v_new_winner := greatest(5.0, least(10.0, v_winner_elo + v_delta));
  v_new_loser  := greatest(5.0, least(10.0, v_loser_elo  - v_delta));

  -- Update profiles (trg_profiles_sync_elo_tier will auto-update elo_tier)
  update profiles set elo_rating = v_new_winner where id = v_match.winner_id;
  update profiles set elo_rating = v_new_loser  where id = v_match.loser_id;

  -- Append elo_history ledger rows
  insert into elo_history (player_id, match_id, elo_before, elo_after, delta, event_type)
  values
    (v_match.winner_id, p_match_id, v_winner_elo, v_new_winner,  v_delta,  'match'),
    (v_match.loser_id,  p_match_id, v_loser_elo,  v_new_loser,  -v_delta, 'match');
end;
$$;

-- ── pg_cron: scheduled background jobs ───────────────────────────────────────

create extension if not exists pg_cron;

-- Auto-confirm matches pending for more than 48 hours (runs every hour)
select cron.schedule(
  'match-auto-confirm',
  '0 * * * *',
  $cron$
    do $inner$
    declare v_id uuid;
    begin
      for v_id in
        select id from public.match_results
        where status = 'pending'
          and created_at < now() - interval '48 hours'
      loop
        update public.match_results
          set status        = 'confirmed',
              auto_confirmed = true,
              confirmed_at  = now()
        where id = v_id;
        perform public.apply_elo_changes(v_id);
      end loop;
    end;
    $inner$ language plpgsql;
  $cron$
);

-- Expire match requests that have passed their expires_at (runs every hour)
select cron.schedule(
  'request-expiry',
  '0 * * * *',
  $cron$
    update public.match_requests
      set status = 'expired'
    where status = 'pending'
      and expires_at < now();
  $cron$
);
