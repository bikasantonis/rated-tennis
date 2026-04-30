# RATED — Database Reference

All schema lives in Supabase (PostgreSQL). Changes are applied via numbered SQL migrations in `supabase/migrations/`. This document describes all tables, the migration log, triggers, helper functions, RLS policies, and scheduled jobs.

---

## Table of Contents

1. [Tables](#1-tables)
2. [Migration Log](#2-migration-log)
3. [Triggers](#3-triggers)
4. [Helper Functions](#4-helper-functions)
5. [Row-Level Security](#5-row-level-security)
6. [Scheduled Jobs (pg_cron)](#6-scheduled-jobs-pg_cron)
7. [Applying Migrations](#7-applying-migrations)

---

## 1. Tables

### `clubs`
Tennis clubs. One club per player in v1.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `name` | varchar(120) | Unique |
| `city` | varchar(80) | |
| `country` | char(2) | ISO 3166-1 alpha-2 |
| `created_by` | uuid FK → `auth.users` | |
| `created_at` / `updated_at` | timestamptz | |

---

### `profiles`
One row per authenticated user. Auto-created by the `handle_new_user` trigger when a row is inserted into `auth.users`.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | FK → `auth.users ON DELETE CASCADE` |
| `display_name` | varchar(60) | Min 2 chars |
| `avatar_url` | text? | Supabase Storage URL |
| `club_id` | uuid FK → `clubs`? | Nullable |
| `elo_rating` | numeric(8,4) | 5.0–10.0; default 5.0 |
| `elo_tier` | varchar(20) | One of 11 values ('5.0'…'10.0'). Auto-maintained by `sync_elo_tier` trigger |
| `role` | varchar(20) | `player` / `organizer` / `admin` |
| `matches_played` | integer | ≥ 0 |
| `matches_won` | integer | ≥ 0 |
| `preferred_language` | char(2) | `en` / `el` |
| `is_public` | boolean | Default true |
| `questionnaire_done` | boolean | Default false; set to true by `seed-elo` Edge Function |
| `peak_elo` | numeric(8,4)? | Career-high ELO; updated by trigger |
| `prestige_score` | numeric(10,4)? | Non-null for RATED (10.0) players only |
| `location_consent` | boolean | Default false; GDPR Art. 6(1)(a) explicit consent |
| `location_consent_at` | timestamptz? | Timestamp of consent grant |
| `home_city` | varchar(100)? | City name from Nominatim reverse geocoding |
| `home_lat` / `home_lng` | double precision? | Rounded to ~1 km precision before storage |
| `notify_nearby_tournaments` | boolean | Default false; independent of `location_consent` |
| `nearby_radius_km` | integer | 25 / 50 / 100 / 150 (check constraint) |
| `deleted_at` | timestamptz? | Soft-delete; anonymise-account Edge Function sets this |
| `created_at` / `updated_at` | timestamptz | |

---

### `questionnaire_responses`
One row per player (unique on `player_id`). Written by the `seed-elo` Edge Function via upsert.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `player_id` | uuid unique FK → `profiles` | |
| `date_of_birth` | date? | Added in migration 021 |
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
| `player_id` | uuid FK → `profiles` | |
| `match_id` | uuid FK → `match_results`? | Null for decay / admin adjustments |
| `elo_before` | numeric(8,4) | |
| `elo_after` | numeric(8,4) | |
| `delta` | numeric(8,4) | `GENERATED ALWAYS AS (elo_after − elo_before) STORED` — cannot disagree with component values |
| `event_type` | varchar(20) | `match` / `tournament_match` / `decay` / `admin_adjustment` |
| `created_at` | timestamptz | |

---

### `match_results`
One row per submitted match. Status lifecycle: `pending` → `confirmed` or `disputed` → `overridden` (admin).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `submitter_id` | uuid FK → `profiles` | Player who submitted the result |
| `winner_id` / `loser_id` | uuid FK → `profiles` | Check constraint: cannot be equal |
| `score` | jsonb | Array of `{winner, loser}` set scores |
| `match_type` | varchar(20) | `friendly` / `tournament` |
| `tournament_id` | uuid FK → `tournaments`? | Nullable |
| `tournament_round` | varchar(20)? | `group` / `round_of_16` / `quarterfinal` / `semifinal` / `final` |
| `status` | varchar(20) | `pending` / `confirmed` / `disputed` / `overridden` |
| `disputed_by` | uuid FK → `profiles`? | Player who disputed |
| `dispute_score` | jsonb? | Opponent's claimed score |
| `resolved_by` | uuid FK → `profiles`? | Admin who resolved the dispute |
| `played_at` | date | |
| `confirmed_at` | timestamptz? | |
| `auto_confirmed` | boolean | Set true by cron job (48 h auto-confirm) |
| `elo_excluded` | boolean | True when tier gap > 1.5 voided the match (migration 019) |
| `created_at` / `updated_at` | timestamptz | |

---

### `match_requests`
Challenge requests between players. Expire after 72 hours via cron job.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `requester_id` | uuid FK → `profiles` | |
| `recipient_id` | uuid FK → `profiles` | Check constraint: cannot equal requester |
| `proposed_at` | timestamptz | Suggested match time |
| `venue_note` | varchar(255)? | |
| `message` | varchar(500)? | |
| `status` | varchar(20) | `pending` / `accepted` / `declined` / `expired` |
| `expires_at` | timestamptz | Default `now() + 72h`; set by cron once past |
| `created_at` / `updated_at` | timestamptz | |

---

### `tournaments`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `organizer_id` | uuid FK → `profiles` | |
| `club_id` | uuid FK → `clubs`? | |
| `name` | varchar(120) | |
| `description` | text? | |
| `format` | varchar(20) | `single_elimination` / `round_robin` |
| `elo_min` / `elo_max` | numeric(8,4) | Eligibility ELO range |
| `max_players` | integer | |
| `registration_open` | boolean | |
| `starts_at` / `ends_at` | date | |
| `status` | varchar(20) | `draft` / `registration_open` / `in_progress` / `completed` / `cancelled` |
| `elo_multiplier` | numeric(4,2) | 1.0–1.5; K-factor multiplier for matches in this tournament |
| `city` / `country` | varchar? / char(2)? | Venue location (event data — not personal data) |
| `venue_lat` / `venue_lng` | double precision? | Used for nearby-tournament queries |
| `created_at` / `updated_at` | timestamptz | |

---

### `tournament_registrations`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `tournament_id` / `player_id` | uuid FK | Unique together — one registration per player per tournament |
| `elo_at_registration` | numeric(8,4) | Snapshot of rating at sign-up (for seeding) |
| `status` | varchar(20) | `pending` / `admitted` / `rejected` |
| `admitted_by` | uuid FK → `profiles`? | Organiser who approved |
| `seed` | integer? | Bracket seeding position |
| `created_at` | timestamptz | |

---

### `tournament_bracket_matches`
Slots in a single-elimination bracket. Added in migration 015.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `tournament_id` | uuid FK → `tournaments` | |
| `round` | integer | Round number (1 = first round) |
| `position` | integer | Slot within the round |
| `player1_id` / `player2_id` | uuid FK → `profiles`? | Nullable until seeded by organiser |
| `winner_id` | uuid FK → `profiles`? | Set when the match is played |
| `match_result_id` | uuid FK → `match_results`? | |
| `created_at` / `updated_at` | timestamptz | |

---

### `organizer_requests`
Self-service requests for the `organizer` role. Added in migration 016.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `player_id` | uuid FK → `profiles` | |
| `club_name` / `club_city` | varchar | Claimed club details |
| `message` | text? | Optional context from the player |
| `status` | varchar(20) | `pending` / `approved` / `denied` |
| `reviewed_by` | uuid FK → `profiles`? | Admin who reviewed |
| `created_at` / `updated_at` | timestamptz | |

---

### `notifications`
One row per notification event. Written only by DB triggers and Edge Functions (using the service role). Never written by a user's own session.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `recipient_id` | uuid FK → `profiles` | |
| `type` | varchar(40) | Notification type string (see NOTIFICATIONS.md) |
| `title` / `body` | varchar | Shown in push banner and in-app panel |
| `reference_id` | uuid? | UUID of the related entity |
| `reference_type` | varchar(40)? | `match_result` / `match_request` / `tournament` / `profile` / `organizer_request` |
| `is_read` | boolean | Default false |
| `created_at` | timestamptz | |

---

## 2. Migration Log

Migrations are applied in filename order via `supabase db push`. Each file is named `NNN_description.sql`.

| # | File | What changed | Key decision |
|---|---|---|---|
| 001 | `001_initial_schema.sql` | 8 core tables | UUID PKs; deferred FK pattern for circular refs (`elo_history ↔ match_results`, `match_results ↔ tournaments`); generated columns for `delta` and `expires_at` |
| 002 | `002_indexes.sql` | 11 indexes | All mandatory from v1; partial indexes on `status = 'pending'` for cron-job filters |
| 003 | `003_rls_policies.sql` | Row-Level Security + helper functions | `SECURITY DEFINER` helpers prevent privilege escalation; service role owns writes to `elo_history` and `notifications` |
| 004 | `004_triggers.sql` | `set_updated_at`, `handle_new_user`, `sync_elo_tier` triggers | `handle_new_user` fires on `auth.users INSERT` so the app never needs a separate profile-create API call |
| 005 | `005_edge_function_stubs.sql` | In-DB documentation comments | No schema changes; `COMMENT ON TABLE` documents each Edge Function's trigger and idempotency contract |
| 006 | `006_elo_scale_change.sql` | ELO scale to 5.0–10.0 | Previous scale was integer-based; 5.0–10.0 maps cleanly to human-readable tier labels |
| 007 | `007_elo_history_types_and_cron.sql` | Widen ELO columns to `numeric(8,4)`; add `apply_elo_changes` function; enable pg_cron; schedule `match-auto-confirm` and `request-expiry` | Sub-decimal precision accumulates silently; display layer rounds to 1 dp |
| 008 | `008_match_format.sql` | `match_type` column on `match_results` | Needed to distinguish friendly vs tournament in ELO calculation |
| 009 | `009_rate_limiting.sql` | Rate-limiting policies | Prevents API abuse at the database level |
| 010 | `010_notification_triggers.sql` | NF-01, NF-03, NF-04, NF-05 DB triggers | Each trigger inserts into `notifications`; the DB webhook fires `send-notification` Edge Function for push delivery |
| 011 | `011_fix_profiles_rls_insert.sql` | Fix RLS INSERT policy on `profiles` | `handle_new_user` runs as `supabase_auth_admin`; the INSERT policy must explicitly permit that role |
| 013 | `013_fix_handle_new_user.sql` | Fix edge case in `handle_new_user` | Short display names from OAuth metadata could fail the `min 2 chars` check; adds `_` suffix as fallback |
| 014 | `014_prestige_score.sql` | `prestige_score` column on `profiles` | Allows RATED (10.0) players to continue gaining/losing without leaving the tier |
| 015 | `015_tournament_bracket.sql` | `tournament_bracket_matches` table + RLS | Stores single-elimination bracket slots; seeded by organiser after registration closes |
| 016 | `016_organizer_requests.sql` | `organizer_requests` table + triggers + email notifications | Self-service organiser request flow; removes need for manual admin role promotion |
| 017 | `017_location.sql` | Location columns on `profiles` + `tournaments`; `haversine_km`, `nearby_tournaments`, `nearby_players`, `nearby_tournament_notify_targets` SQL functions; location indexes | No PostGIS required; pure SQL haversine is accurate enough for 25–150 km radii. All profile location data is GDPR-gated by `location_consent`. |
| 018 | `018_profile_enhancements.sql` | `peak_elo` column on `profiles`; `get_player_rank` RPC | Profile screen shows career-high rating and current global rank |
| 019 | `019_numeric_tiers.sql` | 11 numeric tiers (replaces 6 named tiers); delta clamp [0.01, 0.20]; tournament multiplier cap at 1.5×; friendly void for tier gap > 1.5; rewrite of `apply_elo_changes` | See ELO_SYSTEM.md §5–7 for full rationale |
| 020 | `020_avatars_storage.sql` | `avatars` Storage bucket + RLS | Players can upload/replace/delete their own avatar; public read; RLS prevents cross-user writes |
| 021 | `021_questionnaire_v2.sql` | Drop old subjective columns; add sport-history columns to `questionnaire_responses` | Self-reported level was unreliable; competitive history is objective and age-adjusted |

---

## 3. Triggers

| Trigger name | Table | Event | Function | Purpose |
|---|---|---|---|---|
| `trg_set_updated_at_*` | `profiles`, `match_results`, `match_requests`, `tournaments` | BEFORE UPDATE | `set_updated_at()` | Keeps `updated_at` server-authoritative |
| `trg_handle_new_user` | `auth.users` | AFTER INSERT | `handle_new_user()` | Auto-creates the `profiles` row from OAuth metadata |
| `trg_profiles_sync_elo_tier` | `profiles` | BEFORE INSERT OR UPDATE OF `elo_rating` | `sync_elo_tier()` | Writes the correct tier string in the same transaction as the ELO update |
| `trg_notify_match_submitted` | `match_results` | AFTER INSERT | `notify_match_submitted()` | NF-01: notifies the non-submitting player |
| `trg_notify_match_disputed` | `match_results` | AFTER UPDATE OF `status` | `notify_match_disputed()` | NF-03: notifies original submitter when disputed |
| `trg_notify_match_request_received` | `match_requests` | AFTER INSERT | `notify_match_request_received()` | NF-04: notifies recipient of challenge request |
| `trg_notify_match_request_responded` | `match_requests` | AFTER UPDATE OF `status` | `notify_match_request_responded()` | NF-05: notifies requester of accept/decline |

---

## 4. Helper Functions

| Function | Signature | Security | Purpose |
|---|---|---|---|
| `current_user_role()` | `() → varchar` | DEFINER | Returns `profiles.role` for the calling user. Used in RLS policies. |
| `is_admin()` | `() → boolean` | DEFINER | `current_user_role() = 'admin'` |
| `is_organizer_or_admin()` | `() → boolean` | DEFINER | `current_user_role() IN ('organizer', 'admin')` |
| `apply_elo_changes()` | `(p_match_id uuid) → void` | DEFINER | Core ELO recalculation. Idempotent — no-op if `elo_history` rows already exist. See ELO_SYSTEM.md §5. |
| `sync_elo_tier()` | trigger | DEFINER | Maps `elo_rating` to the correct tier string. |
| `handle_new_user()` | trigger | DEFINER | Creates `profiles` row on new `auth.users` insert. |
| `set_updated_at()` | trigger | — | Sets `updated_at = now()`. |
| `get_display_name()` | `(p_id uuid) → text` | DEFINER | `STABLE` — reads `profiles.display_name`. Used in notification triggers to avoid subqueries. |
| `haversine_km()` | `(lat1, lng1, lat2, lng2 float8) → float8` | — | `IMMUTABLE` — great-circle distance in km. No PostGIS extension needed. |
| `nearby_tournaments()` | `(lat, lng float8, radius_km int) → TABLE` | INVOKER | Returns tournaments within radius, ordered by distance. |
| `nearby_players()` | `(lat, lng float8, radius_km, limit, offset int) → TABLE` | INVOKER | Returns consenting players within radius. |
| `nearby_tournament_notify_targets()` | `(p_tournament_id uuid) → TABLE(user_id uuid)` | DEFINER | Returns user IDs who should receive a push when a tournament opens. Used by `notify-nearby-tournament` Edge Function. |
| `notify_match_excluded()` | `(winner_id, loser_id, match_id uuid) → void` | DEFINER | Inserts two `match_elo_excluded` notification rows when a friendly is voided by tier gap. |
| `get_player_rank()` | `(p_player_id uuid) → integer` | — | Returns the player's current global rank by `elo_rating DESC`. |

---

## 5. Row-Level Security

RLS is enabled on all public tables. Three helper functions (`current_user_role`, `is_admin`, `is_organizer_or_admin`) provide role-based checks.

| Table | Read | Write |
|---|---|---|
| `profiles` | All authenticated (public profiles) | Own profile (player); admin can change `role` |
| `elo_history` | Own rows only | Service role only — via `apply_elo_changes` SECURITY DEFINER |
| `match_results` | All authenticated | Player: submit own; confirm/dispute as participant. Admin: override |
| `match_requests` | Participant only | Requester can insert; participant can update status; requester can delete pending |
| `tournaments` | All authenticated | Organiser: own tournaments. Admin: any |
| `tournament_registrations` | All authenticated | Authenticated: register self. Organiser: own tournament admissions |
| `notifications` | Own (recipient) | Service role only — via DB triggers and Edge Functions |
| `organizer_requests` | Own or admin | Authenticated: insert. Admin: update status |
| `tournament_bracket_matches` | All authenticated | Organiser: own tournament brackets. Admin: any |

**Why service role for `elo_history` and `notifications` writes?** These must never originate from a player's own session. Rating changes go through the Edge Function (which validates the caller is the non-submitter), and notifications are system-generated events. The service role is only available in Edge Functions and DB triggers — not in user or anon sessions.

---

## 6. Scheduled Jobs (pg_cron)

Two jobs registered in migration 007, executed by the `pg_cron` extension:

| Job name | Schedule | What it does |
|---|---|---|
| `match-auto-confirm` | `0 * * * *` (every hour) | Confirms all `pending` match results older than 48 hours; calls `apply_elo_changes`; sends NF-02 notifications to both players |
| `request-expiry` | `0 * * * *` (every hour) | Sets `status = 'expired'` on `match_requests` where `status = 'pending'` and `expires_at < now()` |

---

## 7. Applying Migrations

```bash
# Local dev (requires supabase CLI and Docker)
supabase start
supabase db push          # applies all migrations in order

# Remote (staging or production)
supabase db push --db-url <connection-string>
```

Additive changes (`CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `ALTER TABLE ADD COLUMN IF NOT EXISTS`) are safe to run multiple times. Destructive changes (column drops in migration 021) are not reversible — a rollback migration would be required.

Migration 012 is missing from the sequence (deleted during development). This is not an error — the numbering gap is intentional.
