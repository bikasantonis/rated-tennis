-- ============================================================
-- RATED — Migration 004: Triggers
-- Auto-create profile on auth sign-up; auto-update updated_at
-- ============================================================

-- ── updated_at auto-update ────────────────────────────────────────────────────

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger trg_match_results_updated_at
  before update on public.match_results
  for each row execute function public.set_updated_at();

create trigger trg_match_requests_updated_at
  before update on public.match_requests
  for each row execute function public.set_updated_at();

create trigger trg_tournaments_updated_at
  before update on public.tournaments
  for each row execute function public.set_updated_at();

-- ── auto-create profile on auth.users INSERT ──────────────────────────────────

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, elo_rating, elo_tier, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    5.0,
    'beginner',
    'player'
  );
  return new;
end;
$$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── derive elo_tier from elo_rating on update ─────────────────────────────────

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
