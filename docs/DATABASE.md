# RATED — Database Reference

All schema lives in Supabase (PostgreSQL 17). Changes are applied only through numbered SQL migrations in `supabase/migrations/` — never through the Dashboard. This document covers tables, the migration log, triggers, functions, RLS policies, scheduled jobs, the local → DEV → PROD workflow, and known issues.

> State as of 2026-09-19 (v1.0.0): DEV (`ikjdfsjflzwkhlbootbx`) and PROD (`jkjndgcjyalmglnvvdrd`) are both at migration **029** (Realtime publication), applied to PROD via `./scripts/push-prod.ps1` and verified live cross-device. The full chain replays cleanly on an empty Postgres 17 database (`supabase start` / `supabase db reset`).

---

## Table of Contents

1. [Tables](#1-tables)
2. [Migration Log](#2-migration-log)
3. [Triggers](#3-triggers)
4. [Functions & RPCs](#4-functions--rpcs)
5. [Row-Level Security](#5-row-level-security)
6. [Scheduled Jobs (pg_cron)](#6-scheduled-jobs-pg_cron)
7. [Applying Migrations](#7-applying-migrations)
8. [Known Issues](#8-known-issues)

---

## 1. Tables

### `clubs`
Tennis clubs. One club per player in v1. Only admins can create or edit clubs (RLS).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `name` | varchar(120) | Unique |
| `city` | varchar(80)? | |
| `country` | char(2) | ISO 3166-1 alpha-2 |
| `created_by` | uuid FK → `auth.users` | No `ON DELETE` action |
| `created_at` / `updated_at` | timestamptz | |

---

### `profiles`
One row per authenticated user. Auto-created by `handle_new_user` when a row is inserted into `auth.users`.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | FK → `auth.users` **ON DELETE CASCADE** (see §8) |
| `display_name` | varchar(60) | Min 2 chars |
| `avatar_url` | text? | `avatars` Storage URL, or the OAuth `avatar_url` / `picture` on first sign-up |
| `club_id` | uuid FK → `clubs`? | `ON DELETE SET NULL` |
| `elo_rating` | numeric(8,4) | 5.0–10.0; default 5.0 |
| `elo_tier` | varchar(20) | One of 11 values (`'5.0'`…`'10.0'`), maintained by `sync_elo_tier` |
| `role` | varchar(20) | `player` / `organizer` / `admin`; default `player` |
| `matches_played` | integer | ≥ 0; maintained by `trg_match_counters` (028) |
| `matches_won` | integer | ≥ 0; maintained by `trg_match_counters` (028) |
| `preferred_language` | char(2) | `en` / `el` |
| `is_public` | boolean | Default true; drives leaderboard and profile visibility |
| `questionnaire_done` | boolean | Default false; set to true by `seed-elo` |
| `peak_elo` | numeric(4,1)? | Career-high rating; maintained by `trg_update_peak_elo` |
| `prestige_score` | numeric(10,4)? | Non-null only for RATED (10.0) players; never returned by `get_leaderboard_page` |
| `location_consent` | boolean | Default false; GDPR Art. 6(1)(a) explicit consent |
| `location_consent_at` | timestamptz? | When consent was granted |
| `home_city` | varchar(100)? | City from Nominatim reverse geocoding |
| `home_lat` / `home_lng` | double precision? | Rounded to ~1 km on the client; CHECK requires consent (025) |
| `notify_nearby_tournaments` | boolean | Default false; independent of `location_consent` |
| `nearby_radius_km` | integer | Default 50; one of 25 / 50 / 100 / 150 |
| `court_theme` | text | Default `'roland_garros'`; app values `australian_open` / `roland_garros` / `wimbledon` / `us_open` / `club_classic` |
| `deleted_at` | timestamptz? | Set by `anonymise-account` |
| `created_at` / `updated_at` | timestamptz | |

The registration consent timestamp is not a column: `signUp` stores it as `gdpr_consent_at` in the auth user's metadata (`auth.users.raw_user_meta_data`).

---

### `questionnaire_responses`
One row per player (unique on `player_id`). Written by `seed-elo` via upsert with the service role; users can insert their own row but never update or delete it.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `player_id` | uuid unique FK → `profiles` | `ON DELETE CASCADE` |
| `date_of_birth` | date? | Added in 021 |
| `years_playing` | integer | 0–80 |
| `greek_experience` | varchar(20)? | `recreational` / `national_u200` / `national_20_200` / `national_top20` |
| `international_experience` | varchar(25)? | `none` / `recreational_intl` / `junior_intl` / `professional_adult` / `us_college` |
| `junior_career_high_ranking` | integer? | Required when `junior_intl` |
| `received_atp_wta_point` | boolean? | Required when `professional_adult` |
| `us_college_division` | varchar(30)? | Required when `us_college` |
| `other_sport` | varchar(20)? | `racket_sports` / `other_sports` / `none` |
| `seed_elo` | numeric(8,4) | 5.0–10.0; computed by the seed algorithm |
| `created_at` | timestamptz | |

---

### `elo_history`
Append-only rating ledger. No row is ever updated or deleted.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `player_id` | uuid FK → `profiles` | `ON DELETE CASCADE` |
| `match_id` | uuid FK → `match_results`? | `ON DELETE SET NULL`; null for decay / admin adjustments; indexed (023) |
| `elo_before` | numeric(8,4) | |
| `elo_after` | numeric(8,4) | |
| `delta` | numeric(8,4) | `GENERATED ALWAYS AS (elo_after − elo_before) STORED` |
| `event_type` | varchar(20) | `match` / `tournament_match` / `decay` / `admin_adjustment` (only `match` is written today) |
| `created_at` | timestamptz | |

---

### `match_results`
One row per submitted match. Status lifecycle: `pending` → `confirmed`, or `pending` → `disputed` → `confirmed` (admin approve) / `overridden` (admin override).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `submitter_id` | uuid FK → `profiles` | No `ON DELETE` action |
| `winner_id` / `loser_id` | uuid FK → `profiles` | No `ON DELETE` action; CHECK: not equal |
| `score` | jsonb | Array of `{winner, loser}` set scores |
| `format` | text | Default `bo3_standard`; one of `bo3_standard`, `bo3_super_tb`, `bo3_mini_3rd`, `bo3_mini_super`, `one_full_set`, `one_mini_set` (008) |
| `match_type` | varchar(20) | `friendly` / `tournament` |
| `tournament_id` | uuid FK → `tournaments`? | `ON DELETE SET NULL` |
| `tournament_round` | varchar(20)? | `group` / `round_of_16` / `quarterfinal` / `semifinal` / `final` |
| `status` | varchar(20) | `pending` / `confirmed` / `disputed` / `overridden` |
| `disputed_by` | uuid FK → `profiles`? | |
| `dispute_score` | jsonb? | Opponent's claimed score |
| `resolved_by` | uuid FK → `profiles`? | Admin who resolved the dispute |
| `played_at` | date | |
| `confirmed_at` | timestamptz? | |
| `auto_confirmed` | boolean | Set by the 48 h auto-confirm job |
| `elo_excluded` | boolean | True when a friendly was voided by the > 1.5 tier-gap rule (019) |
| `created_at` / `updated_at` | timestamptz | `created_at` drives the rate limit and auto-confirm |

A match counts as **settled** — shown in feeds and counted in Played/Won — when `status IN ('confirmed','overridden')`.

---

### `match_requests`
Challenges between players ("challenge" in the UI). Expire after 72 hours via cron.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `requester_id` | uuid FK → `profiles` | `ON DELETE CASCADE` |
| `recipient_id` | uuid FK → `profiles` | `ON DELETE CASCADE`; CHECK: not the requester |
| `proposed_at` | timestamptz | Suggested match time |
| `venue_note` | varchar(255)? | |
| `message` | varchar(500)? | |
| `status` | varchar(20) | `pending` / `accepted` / `declined` / `expired` |
| `expires_at` | timestamptz | Default `now() + 72h`; `request-expiry` sets `status = 'expired'` once past |
| `created_at` / `updated_at` | timestamptz | |

---

### `tournaments`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `organizer_id` | uuid FK → `profiles` | No `ON DELETE` action |
| `club_id` | uuid FK → `clubs`? | `ON DELETE SET NULL` |
| `name` | varchar(120) | |
| `description` | text? | |
| `format` | varchar(20) | `single_elimination` / `round_robin` (only single elimination has bracket generation) |
| `elo_min` / `elo_max` | numeric(8,4) | Eligibility range; `elo_min ≥ 5.0` |
| `max_players` | integer | > 0 |
| `registration_open` | boolean | Default true; separate from `status`, which drives the lifecycle and the nearby-tournament webhook |
| `starts_at` / `ends_at` | date | |
| `status` | varchar(20) | `draft` / `registration_open` / `in_progress` / `completed` / `cancelled` |
| `elo_multiplier` | numeric(4,2) | 1.0–1.5 (019); K-factor multiplier for this tournament's matches |
| `city` / `country` | varchar(100)? / char(2)? | Venue location (event data, not personal data) |
| `venue_lat` / `venue_lng` | double precision? | Used for nearby-tournament queries |
| `created_at` / `updated_at` | timestamptz | |

---

### `tournament_registrations`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `tournament_id` / `player_id` | uuid FK | Both `ON DELETE CASCADE`; unique together |
| `elo_at_registration` | **integer** | Rating snapshot at sign-up — never widened to numeric (see §8) |
| `status` | varchar(20) | `pending` / `admitted` / `rejected` |
| `admitted_by` | uuid FK → `profiles`? | Organiser who decided |
| `seed` | integer? | Bracket seeding position |
| `created_at` | timestamptz | |

---

### `tournament_bracket_matches`
Slots in a single-elimination bracket (015). Generated by the organiser from the app; round 1 is filled immediately and later rounds as winners advance.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `tournament_id` | uuid FK → `tournaments` | `ON DELETE CASCADE` |
| `round_number` | integer | ≥ 1 |
| `match_number` | integer | ≥ 1; slot within the round |
| `player1_id` / `player2_id` | uuid FK → `profiles`? | Null until filled |
| `winner_id` | uuid FK → `profiles`? | Set when the organiser records the result |
| `is_bye` | boolean | Default false |
| `created_at` | timestamptz | |

Unique on `(tournament_id, round_number, match_number)`. There is no link to `match_results`.

---

### `organizer_requests`
Self-service requests for the `organizer` role (016). One pending request per player at a time (partial unique index); a player can re-request after a denial.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `player_id` | uuid FK → `profiles` | `ON DELETE CASCADE` |
| `status` | varchar(20) | `pending` / `approved` / `denied` |
| `message` | text? | Optional context from the player |
| `decided_by` | uuid FK → `profiles`? | Admin who decided |
| `decided_at` | timestamptz? | |
| `created_at` | timestamptz | |

---

### `notifications`
One row per notification event. Written by DB triggers, the auto-confirm job, and Edge Functions — never by a user's own session.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `recipient_id` | uuid FK → `profiles` | `ON DELETE CASCADE` |
| `type` | varchar(40) | See [NOTIFICATIONS.md](NOTIFICATIONS.md) |
| `title` | varchar(120) | |
| `body` | varchar(255) | |
| `reference_id` | uuid? | Related entity |
| `reference_type` | varchar(40)? | `match_result` / `match_request` / `tournament` / `profile` / `organizer_request` |
| `is_read` | boolean | Default false |
| `created_at` | timestamptz | |

Partial unique index `idx_notifications_dedup` on `(recipient_id, reference_id, type) WHERE reference_id IS NOT NULL` (024).

---

### Storage: `avatars` bucket
Public read, 2 MB limit, images only (020). Authenticated users can insert, update, and delete objects only under their own `<uid>/` prefix.

---

## 2. Migration Log

Each file is named `NNN_description.sql` and applied in filename order.

| # | File | What changed | Key decision |
|---|---|---|---|
| 001 | `001_initial_schema.sql` | 9 core tables | UUID PKs; deferred FKs for circular refs (`elo_history ↔ match_results`, `match_results ↔ tournaments`); generated `delta` |
| 002 | `002_indexes.sql` | 11 indexes | Partial indexes on `status = 'pending'` for the cron filters |
| 003 | `003_rls_policies.sql` | RLS on all tables + `current_user_role`, `is_admin`, `is_organizer_or_admin` | `SECURITY DEFINER` helpers avoid recursive RLS lookups |
| 004 | `004_triggers.sql` | `set_updated_at`, `handle_new_user`, `sync_elo_tier` | `handle_new_user` fires on `auth.users` INSERT, so the app never creates profiles itself |
| 005 | `005_edge_function_stubs.sql` | In-DB documentation comments | No schema changes |
| 006 | `006_elo_scale_change.sql` | ELO scale to 5.0–10.0 | Maps directly to human-readable tier labels |
| 007 | `007_elo_history_types_and_cron.sql` | Widen ELO columns to `numeric(8,4)`; `apply_elo_changes`; pg_cron with `match-auto-confirm` and `request-expiry` | Sub-decimal precision accumulates; display rounds to 1 dp |
| 008 | `008_match_format.sql` | `match_results.format` — 6 match formats, default `bo3_standard` | Validation depends on the format (mini-sets, super tie-breaks) |
| 009 | `009_rate_limiting.sql` | BEFORE INSERT trigger: max 20 match submissions per submitter per rolling hour | Auth rate limits live in `config.toml` locally and the Dashboard in the cloud |
| 010 | `010_notification_triggers.sql` | NF-01, NF-03, NF-04, NF-05 triggers + `get_display_name` | Triggers only insert rows; the webhook handles push |
| 011 | `011_fix_profiles_rls_insert.sql` | `profiles_insert_trigger` policy | `handle_new_user` runs as `supabase_auth_admin` and needs an explicit INSERT policy |
| 013 | `013_fix_handle_new_user.sql` | Short OAuth display names | Pads names that would fail the 2-char check |
| 014 | `014_prestige_score.sql` | `prestige_score`; `get_leaderboard_page` and `get_rated_rank` RPCs; prestige-aware `apply_elo_changes` | RATED players keep ranking among themselves without leaving 10.0; prestige is never exposed |
| 015 | `015_tournament_bracket.sql` | `tournament_bracket_matches` + RLS | Organiser-generated single-elimination slots |
| 016 | `016_organizer_requests.sql` | `organizer_requests` + submit/decision triggers | Approval grants `profiles.role = 'organizer'` in the DB; push + email via webhooks |
| 017 | `017_location.sql` | Location columns on `profiles` / `tournaments`; `haversine_km`, `nearby_tournaments`, `nearby_players`, `nearby_tournament_notify_targets` | No PostGIS; pure-SQL haversine is accurate enough for 25–150 km |
| 018 | `018_profile_enhancements.sql` | `peak_elo` + `trg_update_peak_elo`; `get_player_rank`; public-profile read policies for registrations and questionnaire answers | Profile shows career high and global rank |
| 019 | `019_numeric_tiers.sql` | 11 numeric tiers; delta clamp [0.01, 0.20]; tournament multiplier cap 1.5×; friendly void for tier gap > 1.5 (`elo_excluded`, `notify_match_excluded`); final `apply_elo_changes` | See ELO_SYSTEM.md §5–7 |
| 020 | `020_avatars_storage.sql` | `avatars` bucket + policies | Own-prefix writes, public read |
| 021 | `021_questionnaire_v2.sql` | Drop subjective questionnaire columns; add sport-history columns | Competitive history is objective and age-adjusted (ADR-13) |
| 022 | `022_fix_handle_new_user_avatar.sql` | Definitive `handle_new_user`: display-name COALESCE, OAuth avatar, `SET search_path = ''`, grants | Resolved three conflicting definitions |
| 023 | `023_elo_history_match_id_index.sql` | `idx_elo_history_match_id` | Removes a full scan from the `apply_elo_changes` idempotency guard |
| 024 | `024_notifications_dedup_and_cron_guard.sql` | `idx_notifications_dedup`; `match-auto-confirm` rewritten with a `status = 'pending'` guard and `ON CONFLICT DO NOTHING` | Overlapping cron runs cannot double-confirm or double-notify |
| 025 | `025_location_consent_constraint.sql` | `chk_location_consent_required` on `profiles` | Coordinates cannot exist without consent |
| 026 | `026_rls_hardening.sql` | `match_results_select` scoped for organisers; explicit deny policies on `questionnaire_responses` UPDATE/DELETE | Closes organiser over-read |
| 027 | `027_court_theme.sql` | `profiles.court_theme` | Court background syncs across devices |
| 028 | `028_match_counters.sql` | `sync_match_counters()` / `trg_match_counters` + one-shot backfill | Played/Won had no writer. A status trigger covers all four confirmation paths (ADR-17) |
| 029 | `029_realtime_publication.sql` | Adds `profiles`, `match_results`, `match_requests`, `notifications` to the `supabase_realtime` publication (idempotent — each table only if missing) | The publication was empty, so no Postgres Changes ever fired and the notification stream was never live. Replica identity is left DEFAULT on purpose: Realtime skips RLS on DELETE events, and DEFAULT sends only the primary key |

Migration 012 is missing from the sequence (deleted during development); the gap is intentional.

---

## 3. Triggers

| Trigger | Table | Event | Function | Purpose |
|---|---|---|---|---|
| `trg_profiles_updated_at`, `trg_match_results_updated_at`, `trg_match_requests_updated_at`, `trg_tournaments_updated_at` | as named | BEFORE UPDATE | `set_updated_at()` | Server-authoritative `updated_at` |
| `trg_on_auth_user_created` | `auth.users` | AFTER INSERT | `handle_new_user()` | Creates the `profiles` row from signup/OAuth metadata |
| `trg_profiles_sync_elo_tier` | `profiles` | BEFORE INSERT OR UPDATE OF `elo_rating` | `sync_elo_tier()` | Writes the tier string in the same transaction |
| `trg_update_peak_elo` | `elo_history` | AFTER INSERT | `update_peak_elo()` | Keeps `profiles.peak_elo` at the career high |
| `trg_match_submission_rate_limit` | `match_results` | BEFORE INSERT | `check_match_submission_rate_limit()` | Rejects the 21st submission within an hour |
| `trg_notify_match_submitted` | `match_results` | AFTER INSERT | `notify_match_submitted()` | NF-01 to the non-submitting player |
| `trg_notify_match_disputed` | `match_results` | AFTER UPDATE OF `status` | `notify_match_disputed()` | NF-03 to the submitter |
| `trg_match_counters` | `match_results` | AFTER INSERT OR UPDATE | `sync_match_counters()` | Maintains `matches_played` / `matches_won` as a match enters or leaves the settled set |
| `trg_notify_match_request_received` | `match_requests` | AFTER INSERT | `notify_match_request_received()` | NF-04 to the recipient |
| `trg_notify_match_request_responded` | `match_requests` | AFTER UPDATE OF `status` | `notify_match_request_responded()` | NF-05 to the requester |
| `trg_organizer_request_submitted` | `organizer_requests` | AFTER INSERT | `notify_admins_organizer_request()` | Notifies every admin |
| `trg_organizer_request_decided` | `organizer_requests` | AFTER UPDATE | `handle_organizer_request_decision()` | On approval sets `role = 'organizer'`; notifies the player either way |

---

## 4. Functions & RPCs

| Function | Signature | Security | Purpose |
|---|---|---|---|
| `current_user_role()` | `() → varchar` | DEFINER | `profiles.role` of the caller; used in RLS |
| `is_admin()` | `() → boolean` | DEFINER | `current_user_role() = 'admin'` |
| `is_organizer_or_admin()` | `() → boolean` | DEFINER | `current_user_role() IN ('organizer','admin')` |
| `apply_elo_changes()` | `(p_match_id uuid) → void` | DEFINER | Core ELO update; idempotent; skips `elo_excluded` matches. Does **not** check status or caller (§8). See ELO_SYSTEM.md §5 |
| `get_leaderboard_page()` | `(p_page int = 0, p_page_size int = 50, p_club_id uuid = null) → TABLE(…, global_rank)` | DEFINER | Public, non-deleted profiles; RATED players first by prestige, then by `elo_rating`. Never returns `prestige_score` |
| `get_player_rank()` | `(p_id uuid) → integer` | DEFINER | One player's global rank, prestige-aware |
| `get_rated_rank()` | `(p_id uuid) → integer` | DEFINER | Rank among RATED players; null below 10.0 |
| `haversine_km()` | `(lat1, lng1, lat2, lng2 float8) → float8` | — | `IMMUTABLE` great-circle distance |
| `nearby_tournaments()` | `(lat, lng float8, radius_km int) → TABLE` | INVOKER | Tournaments within radius, by distance |
| `nearby_players()` | `(lat, lng float8, radius_km, limit, offset int) → TABLE` | INVOKER | Consenting players within radius |
| `nearby_tournament_notify_targets()` | `(p_tournament_id uuid) → TABLE(user_id uuid)` | DEFINER | Push targets for `notify-nearby-tournament` |
| `notify_match_excluded()` | `(winner_id, loser_id, match_id uuid) → void` | DEFINER | Two `match_elo_excluded` notifications |
| `get_display_name()` | `(p_id uuid) → text` | DEFINER | `STABLE` helper for notification text |
| `sync_match_counters()` | trigger | DEFINER | Adjusts counters; no-ops when status and participants are unchanged; reverses the old pair if participants change; locks both profiles in `id` order to avoid deadlocking with `apply_elo_changes` |
| `check_match_submission_rate_limit()` | trigger | DEFINER | 20 submissions / submitter / hour |
| `sync_elo_tier()`, `handle_new_user()`, `update_peak_elo()`, `set_updated_at()`, `notify_*()`, `notify_admins_organizer_request()`, `handle_organizer_request_decision()` | trigger | — | See §3 |

**Grants:** no migration revokes `EXECUTE`, so under the Postgres default every function in `public` can be called over PostgREST (`.rpc()`) by any role. Only `get_leaderboard_page`, `get_rated_rank`, and `get_player_rank` are granted explicitly (to `anon` and `authenticated`).

---

## 5. Row-Level Security

RLS is enabled on every public table. Policies are OR-ed; the service role (Edge Functions, cron) bypasses RLS.

| Table | Read | Write |
|---|---|---|
| `profiles` | Public profiles, own row, admins | Update own row; admins update any. Insert only through `handle_new_user` |
| `questionnaire_responses` | Own, admins, and answers of public profiles with `questionnaire_done` (018) | Insert own; UPDATE and DELETE explicitly denied (026) — `seed-elo` upserts as service role |
| `elo_history` | Own rows, admins | No user writes (policy checks `is_admin()`); written by `apply_elo_changes` |
| `match_results` | Participants (winner, loser, submitter), admins, organisers for matches in their own tournaments (026) | Insert as submitter (or organiser/admin). Update: winner, loser, or admin — **any column** (§8) |
| `match_requests` | Requester or recipient | Insert as requester; update by either party; no delete policy |
| `tournaments` | Any signed-in user | Insert: organiser/admin as `organizer_id`; update: own or admin |
| `tournament_registrations` | Own, organisers/admins, and any registration of a public profile (018) | Insert self (or organiser/admin); update: admin or the tournament's organiser |
| `tournament_bracket_matches` | Any signed-in user | Insert/update: the tournament's organiser only |
| `notifications` | Own | Update own (mark read); inserts come from triggers / service role |
| `organizer_requests` | Own, admins | Insert own; update admins |
| `clubs` | Any signed-in user | Admins |

**Visibility consequences:** because `elo_history` and `match_results` are readable only by participants, another player's profile shows only the matches you played against them, and their ELO sparkline is empty. Leaderboard data and ranks come from `SECURITY DEFINER` RPCs, so they are unaffected.

---

## 6. Scheduled Jobs (pg_cron)

Both jobs were registered in 007; `match-auto-confirm` was rewritten in 024.

| Job | Schedule | What it does |
|---|---|---|
| `match-auto-confirm` | `0 * * * *` (hourly) | For each `pending` match with `created_at` older than 48 h: set `confirmed`, `auto_confirmed = true`, `confirmed_at` (guarded by `WHERE status = 'pending'`); if this run confirmed it, call `apply_elo_changes` and insert NF-02 `match_auto_confirmed` for both players (`ON CONFLICT DO NOTHING`) |
| `request-expiry` | `0 * * * *` (hourly) | `status = 'expired'` on `pending` challenges past `expires_at` |

Check they are active on a project with `SELECT jobname, schedule, active FROM cron.job;`.

---

## 7. Applying Migrations

Three targets, from safest to most dangerous. The CLI is linked to **DEV** by default — confirm with `Get-Content supabase/.temp/project-ref` (should print `ikjdfsjflzwkhlbootbx`) before any linked command.

```bash
# Local (Docker Desktop running) — replays every migration from empty, then supabase/seed.sql
supabase start            # first run pulls images, applies migrations + seed
supabase db reset         # wipe local DB, replay 001→latest + seed (the real test of a migration)
                          # seed accounts: alice@rated.test / bob@rated.test, password123

# DEV cloud project (the default link)
supabase migration list   # Local vs Remote columns — what is pending on dev
supabase db push --dry-run
supabase db push

# PROD — only through the guarded script (links prod, dry run, type "prod", always relinks dev)
./scripts/push-prod.ps1 -DryRunOnly
./scripts/push-prod.ps1                          # migrations
./scripts/push-prod.ps1 -Functions elo-recalculate,send-notification   # + Edge Functions
```

`push-prod.ps1` refuses to run with uncommitted changes, warns (and asks) when not on `main`, shows `migration list` and a dry run, requires typing `prod`, and relinks DEV in a `finally` block even on failure or Ctrl+C. `supabase link` may prompt for each project's database password.

**Adding a migration:**
1. Create `supabase/migrations/029_<description>.sql` — the next number.
2. `supabase db reset` until it replays cleanly, then exercise the affected flows in the app against `.env.local`.
3. `supabase db push` to DEV and verify there.
4. Commit, merge to `main`, then run `./scripts/push-prod.ps1`.

**Rules:**

- **Never edit a migration after it has been pushed** to DEV or PROD — fix forward with a new numbered file. Each database records applied versions in `supabase_migrations.schema_migrations`, so an edited file never re-runs remotely and the environments silently drift.
- **Never change PROD's schema from the Dashboard SQL editor** — every change goes through a migration file, DEV first. Read-only queries there are fine.
- **Database before app, and backward-compatible.** Old app versions stay installed for weeks: add a column → ship the app that uses it → drop the old one in a later migration.
- **`db push` carries only migrations.** Edge Functions, function secrets, Database Webhooks (`notifications` → `send-notification` and `send-email`, `tournaments` → `notify-nearby-tournament`), and Auth provider settings are per-project and must be set on DEV and PROD separately.
- **Seeds are local only.** Never pass `--include-seed` to `db push`.

Additive changes (`CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `ADD COLUMN IF NOT EXISTS`) are safe to re-run. Destructive changes (such as the column drops in 021) are not reversible without a new migration.

---

## 8. Known Issues

Derived from reading the migrations and function code on 2026-09-14; not yet reproduced. Both issues below should be confirmed on the local stack before fixing, and fixed with new migrations. They are tracked in [TODO.md](TODO.md) §2.

### 8.1 Account deletion fails for players with match history
`anonymise-account` first scrubs the profile (name → "Deleted User", PII and location cleared, `deleted_at` set), deletes `questionnaire_responses`, and then hard-deletes the auth user. Because `profiles.id` references `auth.users` **ON DELETE CASCADE**, deleting the auth user also tries to delete the profile row. `match_results.submitter_id / winner_id / loser_id` — as well as `tournaments.organizer_id`, the bracket player columns, `tournament_registrations.admitted_by`, and `organizer_requests.decided_by` — reference `profiles` with no `ON DELETE` action, so that delete is rejected:

- **Player with any match:** the auth delete fails and the function returns 500. The profile is already scrubbed, but the login still exists.
- **Player with no references:** the cascade removes the profile entirely instead of keeping the anonymised row the function intends.

Fix options: drop the cascading FK from `profiles.id` to `auth.users`, so the anonymised row survives the auth delete, or ban and scramble the auth user instead of deleting it. `clubs.created_by → auth.users` (no action) would likewise block deleting an admin who created a club.

### 8.2 ELO can be applied without the opponent's confirmation
- `apply_elo_changes` is `SECURITY DEFINER`, callable by any signed-in user (no `REVOKE`), and does not check `status` or the caller.
- `match_results_update` lets the winner or loser — including the submitter — update any column, including `status`.

A submitter can therefore mark their own match `confirmed` or call `.rpc('apply_elo_changes')` on a `pending` match, bypassing the opponent confirmation that `elo-recalculate` enforces. The admin dispute actions currently rely on the client RPC call. Fix direction: restrict status transitions (a trigger or column-level privileges), revoke `EXECUTE` on `apply_elo_changes` from `anon` and `authenticated`, and move admin approve/override behind an Edge Function or a checked RPC.

### 8.3 `tournament_registrations.elo_at_registration` is an integer
Migration 007 widened every other rating column to `numeric(8,4)` but not this one, so the snapshot is stored as a whole number (7.25 → 7). Anything that seeds or displays from it loses precision.
