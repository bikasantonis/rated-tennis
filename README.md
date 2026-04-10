# RATED

Universal ELO ranking system for Greek tennis club players.

## Stack
- **Flutter** (Dart) — cross-platform client (Android, iOS, Web, Desktop)
- **Supabase** — PostgreSQL, Auth, Edge Functions, Storage (eu-central-1 / Frankfurt)
- **Firebase FCM** — push notifications
- **Riverpod** — state management
- **go_router** — navigation
- **Sentry** — crash reporting

## Quick Start

### 1. Prerequisites
- Flutter ≥ 3.22
- Supabase CLI (`npm install -g supabase`)
- Firebase CLI (`npm install -g firebase-tools`)

### 2. Local Supabase
```bash
supabase start
supabase db push          # applies migrations in order
```

### 3. Environment config
```bash
cp .env.example .env.dev
# Fill in SUPABASE_URL, SUPABASE_ANON_KEY, SENTRY_DSN
```

### 4. Run
```bash
flutter run --dart-define-from-file=.env.dev
```

## Project structure
```
lib/
  main.dart             — app entry, initialises Supabase + Firebase + Sentry
  app.dart              — MaterialApp.router + localisation
  router/               — go_router config (all 14 screens from PRD §7.3)
  theme/                — MD3 colour tokens + typography (PRD §7.1-7.2)
  models/               — Freezed data models (PRD §8)
  providers/            — Riverpod providers
  screens/              — One folder per screen group
  widgets/              — Shared widgets (TierBadge, EloScoreCard, BottomNavShell)

supabase/
  migrations/
    001_initial_schema.sql   — all tables from PRD §8.1
    002_indexes.sql          — mandatory indexes from PRD §8.3
    003_rls_policies.sql     — RLS from permission matrix PRD §5.5
    004_triggers.sql         — updated_at, profile auto-create, elo_tier sync
    005_edge_function_stubs.sql — documents Edge Function bindings
  config.toml
```

## Open questions (from PRD §12.1)
- **Q-01** Should tournament wins apply ELO multiplier > 1.0?
- **Q-02** Exact seed-ELO weighting formula for questionnaire?
- **Q-03** K-factor per tier (default K=32 globally until beta data available)
- **Q-06** Player withdrawal from tournament mid-event handling?

## Milestone targets
| Date | Milestone |
|------|-----------|
| End Apr 2026 | Beta (TestFlight / Internal Play) |
| End Jun 2026 | MVP — all Must-Have features |
| Jul 2026 | Release Candidate |
| Aug 2026 | Public launch |
