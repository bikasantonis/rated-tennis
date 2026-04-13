# RATED

Universal ELO ranking system for tennis club players.

## Stack
- **Flutter** (Dart) — cross-platform client (Android, iOS, Web)
- **Supabase** — PostgreSQL, Auth, Edge Functions, Realtime (eu-central-1 / Frankfurt)
- **OneSignal** — push notifications
- **Riverpod** — state management
- **go_router** — navigation
- **Sentry** — crash reporting
- **geolocator** — device GPS (opt-in, GDPR-compliant)

## Quick Start

### 1. Prerequisites
- Flutter ≥ 3.22
- Supabase CLI (`npm install -g supabase`)

### 2. Local Supabase
```bash
supabase start
supabase db push          # applies all migrations in order
```

### 3. Environment config
```bash
cp .env.example .env.dev
# Fill in SUPABASE_URL, SUPABASE_ANON_KEY, ONESIGNAL_APP_ID, SENTRY_DSN
```

### 4. Run
```bash
flutter run -d chrome --dart-define-from-file=.env.dev --web-port=3000
```

> **Note:** `--web-port=3000` is required for Google OAuth redirect to work correctly.

---

## Key features

| Feature | Description |
|---|---|
| ELO rankings | 5.0–10.0 scale with tier bands (Beginner → Elite). Multiplier tournaments up to 2×. |
| Match flow | Submit → confirm (or dispute) → auto ELO recalculation via Edge Function. |
| Tournaments | Single-elimination & round-robin, bracket generation, organiser management screen. |
| Nearby discovery | Opt-in location features: nearby tournaments tab, nearby players leaderboard filter. |
| Push notifications | OneSignal; match results, requests, nearby tournament openings, organiser events. |
| GDPR | Explicit consent UI, ~1 km location precision, right to withdraw, right to erasure (Art. 17). |
| i18n | English + Greek. |

---

## Project structure

```
lib/
  main.dart               — entry point (Supabase + OneSignal + Sentry init)
  app.dart                — MaterialApp.router + localisation
  router/                 — go_router config
  theme/                  — MD3 colour tokens + typography
  models/                 — Freezed data models
  providers/
    auth_provider.dart    — session, currentProfile, AuthActions
    location_provider.dart — LocationPrefs, LocationActions (GDPR consent flow)
    tournament_provider.dart — tournaments, nearbyTournaments, TournamentActions
    leaderboard_provider.dart — leaderboardPage, nearbyPlayers
    notification_panel_provider.dart
    profile_provider.dart
    ...
  screens/
    home/                 — recent matches feed
    leaderboard/          — global rankings + Near Me filter
    tournament/           — list (Near Me tab) + detail
    match/                — submit, schedule, inbox
    organizer/            — dashboard, per-tournament management
    settings/             — language, location consent, account
    admin/                — dispute resolution
    ...
  services/
    notification_service.dart — OneSignal wrapper + deep-link routing

supabase/
  migrations/
    001_initial_schema.sql        — clubs, profiles, matches, tournaments, notifications
    002_indexes.sql               — performance indexes
    003_rls_policies.sql          — row-level security policies
    004_triggers.sql              — updated_at, profile auto-create, elo_tier sync
    005_edge_function_stubs.sql   — Edge Function webhook bindings
    006_elo_scale_change.sql      — ELO scale adjustment
    007_elo_history_types_and_cron.sql
    008_match_format.sql
    009_rate_limiting.sql
    010_notification_triggers.sql
    011_fix_profiles_rls_insert.sql
    013_fix_handle_new_user.sql
    014_prestige_score.sql
    015_tournament_bracket.sql
    016_organizer_requests.sql
    017_location.sql              — venue location on tournaments, GDPR-gated home location
                                    on profiles, haversine_km(), nearby_tournaments(),
                                    nearby_players(), nearby_tournament_notify_targets()
  functions/
    send-notification/            — DB webhook → OneSignal push
    notify-nearby-tournament/     — fires on registration_open, notifies nearby players
    elo-recalculate/              — ELO delta after match confirmation
    anonymise-account/            — GDPR Art. 17 hard delete + location erasure
    send-email/                   — transactional emails
    seed-elo/                     — post-questionnaire ELO seed
```

---

## GDPR & location data

Location features are **fully opt-in** and gated behind an explicit consent dialog in **Settings → Location**:

- Coordinates are rounded to **~1 km precision** before storage (data minimisation, Art. 5(1)(c)).
- Two independent toggles: *Enable location features* (discovery) and *Notify me about nearby tournaments* (push).
- Withdrawing consent **immediately NULLs** all location columns on the profile row.
- Account deletion clears location data as part of the anonymisation Edge Function (Art. 17).
- Reverse geocoding uses **Nominatim** (OpenStreetMap Foundation, EU-hosted) — no Google Maps API key required.

---

## Milestone targets

| Date | Milestone |
|------|-----------|
| End Apr 2026 | Beta (TestFlight / Internal Play) |
| End Jun 2026 | MVP — all Must-Have features |
| Jul 2026 | Release Candidate |
| Aug 2026 | Public launch |
