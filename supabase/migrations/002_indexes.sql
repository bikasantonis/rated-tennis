-- ============================================================
-- RATED — Migration 002: Required Indexes
-- PRD §8.3 — Mandatory from migration v1
-- ============================================================

-- profiles — leaderboard sort + club filter
create index idx_profiles_elo_rating_club
  on public.profiles (elo_rating desc, club_id);

create index idx_profiles_elo_tier
  on public.profiles (elo_tier);

create index idx_profiles_updated_at
  on public.profiles (updated_at desc);

-- match_results — player match history
create index idx_match_results_winner
  on public.match_results (winner_id, status);

create index idx_match_results_loser
  on public.match_results (loser_id, status);

-- match_results — tournament bracket
create index idx_match_results_tournament
  on public.match_results (tournament_id);

-- match_results — 48-hour auto-confirm cron filter
create index idx_match_results_status_created
  on public.match_results (status, confirmed_at)
  where status = 'pending';

-- elo_history — sparkline chart + partitioning key
create index idx_elo_history_player_created
  on public.elo_history (player_id, created_at desc);

-- tournament_registrations — registered player list
create index idx_tournament_reg_tournament
  on public.tournament_registrations (tournament_id, status);

create index idx_tournament_reg_player
  on public.tournament_registrations (player_id);

-- match_requests — match inbox
create index idx_match_requests_recipient
  on public.match_requests (recipient_id, status);

-- match_requests — expiry cron filter
create index idx_match_requests_expiry
  on public.match_requests (expires_at, status)
  where status = 'pending';

-- notifications — inbox + badge count
create index idx_notifications_recipient
  on public.notifications (recipient_id, is_read, created_at desc);
