-- ============================================================
-- RATED — Migration 003: Row Level Security Policies
-- PRD §5.5 — Permission matrix
-- ============================================================

-- Enable RLS on all application tables
alter table public.profiles               enable row level security;
alter table public.clubs                  enable row level security;
alter table public.questionnaire_responses enable row level security;
alter table public.elo_history            enable row level security;
alter table public.match_results          enable row level security;
alter table public.match_requests         enable row level security;
alter table public.tournaments            enable row level security;
alter table public.tournament_registrations enable row level security;
alter table public.notifications          enable row level security;

-- ── Helper functions ─────────────────────────────────────────────────────────

create or replace function public.current_user_role()
returns varchar
language sql
stable
security definer
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
as $$
  select current_user_role() = 'admin'
$$;

create or replace function public.is_organizer_or_admin()
returns boolean
language sql
stable
security definer
as $$
  select current_user_role() in ('organizer','admin')
$$;

-- ── profiles ─────────────────────────────────────────────────────────────────

-- Anyone authenticated can read public profiles
create policy "profiles_select_public"
  on public.profiles for select
  using (is_public = true or id = auth.uid() or is_admin());

-- Players can update their own profile (except role and elo fields)
create policy "profiles_update_own"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- Admins can update any profile (e.g., assign organizer role)
create policy "profiles_update_admin"
  on public.profiles for update
  using (is_admin());

-- ── questionnaire_responses ───────────────────────────────────────────────────

create policy "questionnaire_select_own"
  on public.questionnaire_responses for select
  using (player_id = auth.uid() or is_admin());

create policy "questionnaire_insert_own"
  on public.questionnaire_responses for insert
  with check (player_id = auth.uid());

-- ── elo_history ───────────────────────────────────────────────────────────────

create policy "elo_history_select"
  on public.elo_history for select
  using (
    player_id = auth.uid()
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.is_public = true and p.id = player_id
    )
    or is_admin()
  );

-- Only Edge Functions (service role) may insert elo_history rows
create policy "elo_history_insert_service"
  on public.elo_history for insert
  with check (is_admin());

-- ── match_results ─────────────────────────────────────────────────────────────

-- Players can see their own matches; organizers see tournament matches they manage
create policy "match_results_select"
  on public.match_results for select
  using (
    winner_id = auth.uid()
    or loser_id = auth.uid()
    or submitter_id = auth.uid()
    or is_organizer_or_admin()
  );

-- Players and organizers can submit match results
create policy "match_results_insert"
  on public.match_results for insert
  with check (submitter_id = auth.uid() or is_organizer_or_admin());

-- Players can update status (confirm/dispute) on their own matches only;
-- admins can override
create policy "match_results_update"
  on public.match_results for update
  using (
    winner_id = auth.uid()
    or loser_id = auth.uid()
    or is_admin()
  );

-- ── match_requests ────────────────────────────────────────────────────────────

create policy "match_requests_select"
  on public.match_requests for select
  using (requester_id = auth.uid() or recipient_id = auth.uid());

create policy "match_requests_insert"
  on public.match_requests for insert
  with check (requester_id = auth.uid());

create policy "match_requests_update"
  on public.match_requests for update
  using (requester_id = auth.uid() or recipient_id = auth.uid());

-- ── tournaments ───────────────────────────────────────────────────────────────

-- All authenticated users can browse tournaments
create policy "tournaments_select"
  on public.tournaments for select
  using (auth.uid() is not null);

-- Only organizers and admins can create tournaments
create policy "tournaments_insert"
  on public.tournaments for insert
  with check (is_organizer_or_admin() and organizer_id = auth.uid());

-- Organizers can update their own tournaments; admins can update any
create policy "tournaments_update"
  on public.tournaments for update
  using (organizer_id = auth.uid() or is_admin());

-- ── tournament_registrations ──────────────────────────────────────────────────

create policy "tournament_reg_select"
  on public.tournament_registrations for select
  using (
    player_id = auth.uid()
    or is_organizer_or_admin()
    or exists (
      select 1 from public.tournaments t
      where t.id = tournament_id and t.organizer_id = auth.uid()
    )
  );

create policy "tournament_reg_insert"
  on public.tournament_registrations for insert
  with check (player_id = auth.uid() or is_organizer_or_admin());

create policy "tournament_reg_update"
  on public.tournament_registrations for update
  using (
    is_admin()
    or exists (
      select 1 from public.tournaments t
      where t.id = tournament_id and t.organizer_id = auth.uid()
    )
  );

-- ── notifications ─────────────────────────────────────────────────────────────

create policy "notifications_select_own"
  on public.notifications for select
  using (recipient_id = auth.uid());

create policy "notifications_update_own"
  on public.notifications for update
  using (recipient_id = auth.uid());

-- Only service role (Edge Functions) can insert notifications
create policy "notifications_insert_service"
  on public.notifications for insert
  with check (is_admin());

-- ── clubs ─────────────────────────────────────────────────────────────────────

create policy "clubs_select"
  on public.clubs for select
  using (auth.uid() is not null);

create policy "clubs_insert"
  on public.clubs for insert
  with check (is_admin());

create policy "clubs_update"
  on public.clubs for update
  using (is_admin());
