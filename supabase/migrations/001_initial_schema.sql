-- ============================================================
-- RATED — Migration 001: Initial Schema
-- PRD §8 — All entities with constraints and defaults
-- ============================================================

-- Enable UUID generation
create extension if not exists "pgcrypto";

-- ── clubs ────────────────────────────────────────────────────────────────────
create table public.clubs (
  id          uuid primary key default gen_random_uuid(),
  name        varchar(120) not null unique,
  city        varchar(80),
  country     char(2) not null,
  created_by  uuid not null references auth.users(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ── profiles ─────────────────────────────────────────────────────────────────
-- Extends auth.users via 1-to-1 relationship.
-- Row auto-created by trigger on auth.users INSERT (see 004_triggers.sql).
create table public.profiles (
  id                  uuid primary key references auth.users(id) on delete cascade,
  display_name        varchar(60) not null check (char_length(display_name) >= 2),
  avatar_url          text,
  club_id             uuid references public.clubs(id) on delete set null,
  elo_rating          numeric(4,1) not null default 5.0 check (elo_rating between 5.0 and 10.0),
  elo_tier            varchar(20) not null default 'bronze'
                        check (elo_tier in ('beginner','bronze','silver','gold','platinum','elite')),
  role                varchar(20) not null default 'player'
                        check (role in ('player','organizer','admin')),
  matches_played      integer not null default 0 check (matches_played >= 0),
  matches_won         integer not null default 0 check (matches_won >= 0),
  preferred_language  char(2) not null default 'en' check (preferred_language in ('en','el')),
  is_public           boolean not null default true,
  questionnaire_done  boolean not null default false,
  deleted_at          timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ── questionnaire_responses ──────────────────────────────────────────────────
create table public.questionnaire_responses (
  id                   uuid primary key default gen_random_uuid(),
  player_id            uuid not null unique references public.profiles(id) on delete cascade,
  playing_frequency    varchar(20) not null
                         check (playing_frequency in ('rarely','monthly','weekly','multiple_weekly')),
  self_assessed_level  varchar(20) not null
                         check (self_assessed_level in ('beginner','intermediate','advanced','competitive')),
  years_playing        integer not null check (years_playing between 0 and 50),
  preferred_surface    varchar(20)
                         check (preferred_surface in ('clay','hard','grass','indoor','no_preference')),
  has_competed         boolean not null,
  seed_elo             numeric(4,1) not null check (seed_elo between 5.0 and 10.0),
  created_at           timestamptz not null default now()
);

-- ── elo_history ──────────────────────────────────────────────────────────────
-- Append-only ledger — never updated or deleted.
create table public.elo_history (
  id          uuid primary key default gen_random_uuid(),
  player_id   uuid not null references public.profiles(id) on delete cascade,
  match_id    uuid,  -- FK added after match_results table is created (below)
  elo_before  integer not null,
  elo_after   integer not null,
  delta       integer not null,
  event_type  varchar(20) not null
                check (event_type in ('match','tournament_match','decay','admin_adjustment')),
  created_at  timestamptz not null default now()
);

-- ── match_results ─────────────────────────────────────────────────────────────
create table public.match_results (
  id                uuid primary key default gen_random_uuid(),
  submitter_id      uuid not null references public.profiles(id),
  winner_id         uuid not null references public.profiles(id),
  loser_id          uuid not null references public.profiles(id),
  score             jsonb not null,   -- [{winner: int, loser: int}, ...]  max 5 elements
  match_type        varchar(20) not null check (match_type in ('friendly','tournament')),
  tournament_id     uuid,             -- FK → tournaments added after that table
  tournament_round  varchar(20)
                      check (tournament_round in ('group','round_of_16','quarterfinal','semifinal','final')),
  status            varchar(20) not null default 'pending'
                      check (status in ('pending','confirmed','disputed','overridden')),
  disputed_by       uuid references public.profiles(id),
  dispute_score     jsonb,
  resolved_by       uuid references public.profiles(id),
  played_at         date not null,
  confirmed_at      timestamptz,
  auto_confirmed    boolean not null default false,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  -- A player cannot be both winner and loser
  check (winner_id <> loser_id)
);

-- Back-fill FK from elo_history → match_results
alter table public.elo_history
  add constraint elo_history_match_id_fkey
  foreign key (match_id) references public.match_results(id) on delete set null;

-- ── match_requests ────────────────────────────────────────────────────────────
create table public.match_requests (
  id            uuid primary key default gen_random_uuid(),
  requester_id  uuid not null references public.profiles(id) on delete cascade,
  recipient_id  uuid not null references public.profiles(id) on delete cascade,
  proposed_at   timestamptz not null,
  venue_note    varchar(255),
  message       varchar(500),
  status        varchar(20) not null default 'pending'
                  check (status in ('pending','accepted','declined','expired')),
  expires_at    timestamptz not null default (now() + interval '72 hours'),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  check (requester_id <> recipient_id)
);

-- ── tournaments ───────────────────────────────────────────────────────────────
create table public.tournaments (
  id                 uuid primary key default gen_random_uuid(),
  organizer_id       uuid not null references public.profiles(id),
  club_id            uuid references public.clubs(id) on delete set null,
  name               varchar(120) not null,
  description        text,
  format             varchar(20) not null
                       check (format in ('single_elimination','round_robin')),
  elo_min            integer not null check (elo_min >= 100),
  elo_max            integer not null check (elo_max >= elo_min),
  max_players        integer not null check (max_players > 0),
  registration_open  boolean not null default true,
  starts_at          date not null,
  ends_at            date,
  status             varchar(20) not null default 'draft'
                       check (status in ('draft','registration_open','in_progress','completed','cancelled')),
  elo_multiplier     numeric(4,2) not null default 1.0
                       check (elo_multiplier between 1.0 and 2.0),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- Back-fill FK from match_results → tournaments
alter table public.match_results
  add constraint match_results_tournament_id_fkey
  foreign key (tournament_id) references public.tournaments(id) on delete set null;

-- ── tournament_registrations ──────────────────────────────────────────────────
create table public.tournament_registrations (
  id                   uuid primary key default gen_random_uuid(),
  tournament_id        uuid not null references public.tournaments(id) on delete cascade,
  player_id            uuid not null references public.profiles(id) on delete cascade,
  elo_at_registration  integer not null,
  status               varchar(20) not null default 'pending'
                         check (status in ('pending','admitted','rejected')),
  admitted_by          uuid references public.profiles(id),
  seed                 integer,
  created_at           timestamptz not null default now(),

  unique (tournament_id, player_id)
);

-- ── notifications ─────────────────────────────────────────────────────────────
create table public.notifications (
  id              uuid primary key default gen_random_uuid(),
  recipient_id    uuid not null references public.profiles(id) on delete cascade,
  type            varchar(40) not null,
  title           varchar(120) not null,
  body            varchar(255) not null,
  reference_id    uuid,
  reference_type  varchar(40),
  is_read         boolean not null default false,
  created_at      timestamptz not null default now()
);
