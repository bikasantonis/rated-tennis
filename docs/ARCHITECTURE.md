# RATED — Architecture & File Reference

> Auto-generated scaffold documentation. Updated: 2026-03-29.
> Every file created in the initial scaffold is described here with its purpose, key decisions, and how it connects to the PRD.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Directory Map](#2-directory-map)
3. [Root Config Files](#3-root-config-files)
4. [lib/ — Flutter Source](#4-lib--flutter-source)
   - [Entry Point](#41-entry-point)
   - [Router](#42-router)
   - [Theme](#43-theme)
   - [Models](#44-models)
   - [Providers](#45-providers)
   - [Widgets](#46-widgets)
   - [Screens](#47-screens)
5. [supabase/ — Database & Backend](#5-supabase--database--backend)
   - [Migration 001 — Schema](#51-migration-001--initial-schema)
   - [Migration 002 — Indexes](#52-migration-002--indexes)
   - [Migration 003 — RLS Policies](#53-migration-003--rls-policies)
   - [Migration 004 — Triggers](#54-migration-004--triggers)
   - [Migration 005 — Edge Function Stubs](#55-migration-005--edge-function-stubs)
6. [How the layers connect](#6-how-the-layers-connect)
7. [First-run checklist](#7-first-run-checklist)

---

## 1. Project Overview

**RATED** is a cross-platform Flutter application providing a universal ELO ranking system for Greek tennis club players. Players receive a profile and rating from a short questionnaire; every confirmed match updates both players' ratings via the ELO algorithm. The app supports match scheduling, dispute resolution, and tournament management with bracket generation.

| Layer | Technology | PRD ref |
|---|---|---|
| Frontend | Flutter 3.22+ / Dart | §4.2 |
| State management | Riverpod 2 (code-gen) | §4.2 |
| Navigation | go_router 14 (ShellRoute) | §7.3.2 |
| Backend / DB | Supabase (PostgreSQL + PostgREST) | §4.2 |
| Auth | Supabase Auth + Google + Apple | §5.2 |
| Push notifications | OneSignal via Supabase Edge Function | §5.4 |
| Error monitoring | Sentry | §11.5 |
| CI/CD | GitHub Actions + Fastlane | §11.4 |

---

## 2. Directory Map

```
rated/
├── lib/
│   ├── main.dart                        App entry point
│   ├── app.dart                         MaterialApp.router + i18n
│   ├── router/
│   │   └── app_router.dart              go_router config (all 14 screens)
│   ├── theme/
│   │   ├── app_colors.dart              Design tokens (PRD §7.2)
│   │   └── app_theme.dart               MD3 ThemeData light + dark
│   ├── models/
│   │   ├── profile.dart                 profiles table model
│   │   ├── match_result.dart            match_results table model
│   │   ├── match_request.dart           match_requests table model
│   │   ├── tournament.dart              tournaments table model
│   │   ├── elo_history.dart             elo_history table model
│   │   └── notification_item.dart       notifications table model
│   ├── providers/
│   │   └── auth_provider.dart           Session stream + current profile
│   ├── widgets/
│   │   ├── bottom_nav_shell.dart        MD3 NavigationBar shell
│   │   ├── tier_badge.dart              ELO tier colour badge
│   │   └── elo_score_card.dart          Dashboard ELO card widget
│   └── screens/
│       ├── onboarding/                  SCR-01
│       ├── auth/                        SCR-02
│       ├── questionnaire/               SCR-03
│       ├── home/                        SCR-04
│       ├── leaderboard/                 SCR-05
│       ├── profile/                     SCR-06
│       ├── match/                       SCR-07, SCR-08, SCR-09
│       ├── tournament/                  SCR-10, SCR-11
│       ├── organizer/                   SCR-12
│       ├── settings/                    SCR-13
│       └── admin/                       SCR-14
├── supabase/
│   ├── config.toml                      Local dev stack config
│   └── migrations/
│       ├── 001_initial_schema.sql       8 tables with constraints
│       ├── 002_indexes.sql              11 mandatory indexes
│       ├── 003_rls_policies.sql         Row Level Security
│       ├── 004_triggers.sql             updated_at, profile create, elo_tier sync
│       └── 005_edge_function_stubs.sql  Edge Function binding docs
├── assets/images/                       Static assets (placeholder)
├── docs/
│   ├── ARCHITECTURE.md                  ← this file
│   └── TODO.md                          Tracked implementation tasks
├── pubspec.yaml
├── analysis_options.yaml
├── .env.example
└── .gitignore
```

---

## 3. Root Config Files

### `pubspec.yaml`
Declares all Dart dependencies. Key groups:
- **Supabase** (`supabase_flutter`) — replaces Firebase Firestore/Auth used in the prototype
- **Auth providers** (`google_sign_in`, `sign_in_with_apple`) — required by Apple App Store when any OAuth is offered
- **Push notifications** (`onesignal_flutter`) — OneSignal SDK; no Firebase dependency; handles APNs automatically
- **State** (`flutter_riverpod`, `riverpod_annotation`) — code-gen providers via `@riverpod`
- **Navigation** (`go_router`) — declarative URL-based routing with deep-link support
- **Models** (`freezed_annotation`, `json_annotation`) — immutable, serialisable data classes
- **Fonts** (`google_fonts`) — Inter (body) + Barlow Condensed (ELO numbers) per PRD §7.1
- **Charts** (`fl_chart`) — ELO sparkline on player profile (SCR-06)

### `analysis_options.yaml`
Enables `custom_lint` + `riverpod_lint` which statically check that providers are used correctly (catches missing `ref.watch` vs `ref.read` errors at analysis time, not runtime).

### `.env.example`
Template for the three environment files (`.env.dev`, `.env.staging`, `.env.production`). Values are injected at build time via `--dart-define-from-file` so no secrets ever enter the source tree. Required keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`, `APP_ENV`, `GOOGLE_CLIENT_ID`, `ONESIGNAL_APP_ID`.

### `.gitignore`
Excludes generated Dart files (`*.freezed.dart`, `*.g.dart`), all `.env.*` files, `google-services.json`, and `GoogleService-Info.plist` to prevent secret leakage.

---

## 4. lib/ — Flutter Source

### 4.1 Entry Point

#### `lib/main.dart`
Initialises all three services in order before `runApp`:
1. `OneSignal.initialize` — called with `ONESIGNAL_APP_ID` (injected via `--dart-define-from-file`); followed by `requestPermission(false)` which shows the iOS system permission prompt without force-requesting
2. `Supabase.initialize` — uses PKCE auth flow (more secure than implicit on mobile)
3. `SentryFlutter.init` — wraps `runApp` so uncaught errors are captured

The app is wrapped in `ProviderScope` (Riverpod root) before being handed to Sentry's runner.

> **No Firebase dependency.** `firebase_options.dart` was removed. OneSignal handles APNs certificate provisioning automatically via its dashboard; no `google-services.json` or `GoogleService-Info.plist` required for push.

#### `lib/app.dart`
`RatedApp` is a `ConsumerWidget` that reads `appRouterProvider` (the go_router instance). Using `MaterialApp.router` instead of `MaterialApp` enables go_router's declarative navigation. Both `theme` and `darkTheme` are provided from day one (PRD §7.1 — dark mode must be defined at scaffold, not added later). `ThemeMode.system` respects the device setting with no manual toggle in v1.

---

### 4.2 Router

#### `lib/router/app_router.dart`

The central navigation configuration. Key design decisions:

**`AppRoutes` constants** — All path strings live in one `abstract final class` so screens reference `AppRoutes.home` rather than string literals, preventing typo-based routing bugs.

**`appRouterProvider`** — A `@riverpod`-annotated `GoRouter` factory. Because it watches `authStateProvider` and `currentProfileProvider`, the router automatically rebuilds (and re-evaluates the `redirect` callback) whenever auth state changes — no manual navigation calls needed after login/logout.

**Redirect logic** (PRD §7.3.2):
1. Unauthenticated → `/login`
2. Authenticated but `questionnaire_done = false` → `/questionnaire`
3. Authenticated + done, trying to visit auth screens → `/home`

**`ShellRoute`** — wraps the four bottom-nav destinations (`/home`, `/leaderboard`, `/matches`, `/tournaments`) so the `BottomNavShell` scaffold persists across those tabs while nested routes (e.g. `/leaderboard/:id` for a player profile) push on top without destroying the shell.

**Transition helpers** — `_slide` uses MD3's standard curve (300 ms `easeInOut`); `_fade` uses the emphasised decelerate variant (350 ms) for full-screen auth replacements per PRD §7.1 Motion tokens.

**Role-gated routes** (`/organizer`, `/admin/disputes`) — declared in the router but not surfaced in the bottom nav. The organizer dashboard is accessible via a profile overflow menu; the admin disputes screen via a deep link only.

---

### 4.3 Theme

#### `lib/theme/app_colors.dart`
All colour hex values from PRD §7.2.1 (light) and §7.2.2 (dark override). Declared as `abstract final class` constants so they can never be instantiated. The tier badge colours (§7.2.3) are here too, keeping all design tokens in one auditable place.

> **WCAG note:** All values were verified at ≥ 4.5:1 contrast ratio as required by PRD §6.1. Do not change hex values without re-running contrast checks.

#### `lib/theme/app_theme.dart`
Two `ThemeData` objects (`light`, `dark`) built with `ColorScheme.fromSeed(seedColor: AppColors.primary)` — the MD3 tonal palette system derives all 30 colour roles automatically from the seed. Manual overrides are applied only where the PRD specifies exact values (e.g. `tertiary`, `surface`).

`AppTheme` also defines the three border-radius constants used app-wide:
- `radiusGlobal = 12` — cards, inputs, dialogs
- `radiusPill = 999` — tier badges, chips
- `radiusButton = 20` — MD3 button default

Typography uses `google_fonts` with **Barlow Condensed Bold** for `displayLarge`–`headlineMedium` (ELO numbers, ranking figures) and **Inter** for all body/UI text.

---

### 4.4 Models

All six models use **Freezed** for immutability, `copyWith`, equality, and `fromJson`/`toJson`. After scaffold, run `dart run build_runner build` to generate the `.freezed.dart` and `.g.dart` files.

| File | Supabase table | Notable |
|---|---|---|
| `profile.dart` | `profiles` | `EloTier` enum with `fromRating()` factory mirrors the trigger logic in SQL |
| `match_result.dart` | `match_results` | `SetScore` is a nested Freezed class matching the JSONB `score` column structure |
| `match_request.dart` | `match_requests` | `expiresAt` is stored in DB as a generated column (`created_at + 72h`) |
| `tournament.dart` | `tournaments` | `eloMultiplier` maps to `NUMERIC(4,2)`, range 1.0–2.0 per PRD §8.1.7 |
| `elo_history.dart` | `elo_history` | Append-only; `delta` is a generated column in PostgreSQL |
| `notification_item.dart` | `notifications` | `referenceType` enables polymorphic deep-link routing on tap |

---

### 4.5 Providers

#### `lib/providers/auth_provider.dart`

**`authStateProvider`** — a `StreamProvider` wrapping Supabase's `onAuthStateChange` stream. Emits `Session?`; null = logged out. The go_router watches this to trigger redirects automatically.

**`currentProfileProvider`** — a `FutureProvider` that fetches the authenticated user's `profiles` row from Supabase. Uses an explicit `.select()` column list (never `SELECT *`) per PRD §6.2.3 to reduce payload and prevent accidental PII leakage.

---

### 4.6 Widgets

#### `lib/widgets/bottom_nav_shell.dart`
MD3 `NavigationBar` with 4 destinations matching PRD §7.3.1. The active destination is derived from `GoRouterState.of(context).matchedLocation` using `startsWith` so that nested routes (e.g. a tournament detail page) keep the Tournaments tab highlighted. Tapping a destination calls `context.go()` rather than `context.push()` to avoid stacking the same tab multiple times.

#### `lib/widgets/tier_badge.dart`
Renders the pill-shaped tier badge with the correct fill/text colour for all 6 tiers from `AppColors`. Uses `Semantics(label: '${tier.label} tier')` for screen reader support per PRD §6.1 Accessibility. The `small` flag supports compact display on leaderboard rows.

#### `lib/widgets/elo_score_card.dart`
Dashboard ELO card (PRD §7.4 SCR-04 wireframe). Displays the ELO number in Barlow Condensed 72pt, the tier badge below it, and a three-stat row (Played / Won / Win%). Tapping the card navigates to the player's own profile (SCR-06) — **wiring not yet implemented**.

---

### 4.7 Screens

All screens are fully implemented stubs: they compile, route correctly, and display a placeholder. Implementation details are tracked in [TODO.md](TODO.md).

| Screen | File | PRD ID | Auth | Notes |
|---|---|---|---|---|
| Onboarding | `onboarding/onboarding_screen.dart` | SCR-01 | No | 3-slide PageView with animated indicator dots. CTA on last slide goes to `/login`. |
| Login / Register | `auth/login_screen.dart` | SCR-02 | No | Tabbed — Login + Register. Google and Apple Sign-In button stubs present. GDPR consent checkbox stub in Register tab. |
| Questionnaire | `questionnaire/questionnaire_screen.dart` | SCR-03 | Yes | One-time screen; router blocks access once `questionnaire_done = true`. |
| Home / Dashboard | `home/home_screen.dart` | SCR-04 | Yes | `EloScoreCard` wired to live `currentProfileProvider`. Two FABs: Submit Match and Schedule Match. |
| Leaderboard | `leaderboard/leaderboard_screen.dart` | SCR-05 | Yes | Stub — needs paginated Supabase query. |
| Player Profile | `profile/profile_screen.dart` | SCR-06 | Yes | `playerId` param: null = own, non-null = other. Edit button conditional on ownership. |
| Submit Match | `match/submit_match_screen.dart` | SCR-07 | Yes | Stub — needs score entry form with set validation. |
| Match Inbox | `match/match_inbox_screen.dart` | SCR-08 | Yes | Stub — pending results + requests combined. |
| Schedule Match | `match/schedule_match_screen.dart` | SCR-09 | Yes | Stub — needs ±150 ELO player browse list. |
| Tournaments List | `tournament/tournaments_list_screen.dart` | SCR-10 | Yes | Stub — Open/Registered/Past filter tabs. |
| Tournament Detail | `tournament/tournament_detail_screen.dart` | SCR-11 | Yes | Stub — bracket viewer (single-elim tree or round-robin grid). |
| Organizer Dashboard | `organizer/organizer_dashboard_screen.dart` | SCR-12 | Yes (Organizer+) | Role-gated — not in bottom nav. |
| Settings | `settings/settings_screen.dart` | SCR-13 | Yes | Language toggle EN/EL, notification prefs, account deletion. |
| Dispute Resolution | `admin/dispute_resolution_screen.dart` | SCR-14 | Yes (Admin) | Accessible via `/admin/disputes` deep link only. |

---

## 5. supabase/ — Database & Backend

Migrations are applied in order via `supabase db push`. Each file is idempotent-safe for additive changes.

### 5.1 Migration 001 — Initial Schema

Creates all 8 tables from PRD §8.1 in dependency order (clubs → profiles → questionnaire_responses → elo_history → match_results → match_requests → tournaments → tournament_registrations → notifications). Deferred FK additions (`ALTER TABLE ... ADD CONSTRAINT`) are used where two tables reference each other (e.g. `elo_history` ↔ `match_results`, `match_results` ↔ `tournaments`).

Key design decisions:
- **UUID PKs everywhere** — prevents ID enumeration attacks; supports future federation (PRD §6.2.1)
- `elo_history.delta` — `GENERATED ALWAYS AS (elo_after - elo_before) STORED` so it can never disagree with the two component values
- `match_requests.expires_at` — `GENERATED ALWAYS AS (created_at + interval '72 hours') STORED` so expiry is computed once at insert and never needs updating
- `profiles.elo_tier` stored as denormalised column (not a view) to make leaderboard queries O(1) per row

### 5.2 Migration 002 — Indexes

11 indexes covering every query pattern identified in PRD §8.3. All are **mandatory from migration v1** — omitting any causes full-table scans on the most frequent operations. Partial indexes (e.g. `WHERE status = 'pending'`) are used on the cron-job filter columns to keep the index small.

### 5.3 Migration 003 — RLS Policies

Implements the permission matrix from PRD §5.5. Two PostgreSQL helper functions (`current_user_role()`, `is_admin()`, `is_organizer_or_admin()`) are declared `SECURITY DEFINER` so they read from the `profiles` table with the function owner's privileges, not the caller's. This prevents privilege escalation via RLS bypass.

Key policy patterns:
- **profiles** — public profiles readable by all authenticated users; own profile always readable; only admins can change `role`
- **elo_history** — only the service role (Edge Functions) can insert; players can read their own
- **notifications** — only the service role can insert; players can only read/update their own

### 5.4 Migration 004 — Triggers

Four trigger types:

1. **`set_updated_at()`** — applied to `profiles`, `match_results`, `match_requests`, `tournaments`. Ensures `updated_at` is always server-set.
2. **`handle_new_user()`** — fires `AFTER INSERT ON auth.users`. Creates the corresponding `profiles` row automatically using `display_name` from OAuth metadata or the email prefix as fallback. This means the app never has to call a separate "create profile" endpoint after sign-up.
3. **`sync_elo_tier()`** — fires `BEFORE INSERT OR UPDATE OF elo_rating ON profiles`. Keeps `elo_tier` in sync with `elo_rating` using the tier boundary logic from PRD §7.2.3. This trigger runs synchronously in the same transaction as the ELO update.

### 5.5 Migration 005 — Edge Function Stubs

Documents the five Edge Functions that must be deployed separately. This SQL file does not create functions — it serves as in-database documentation via `COMMENT ON TABLE` and SQL block comments describing each function's trigger, action, and idempotency contract.

| Function | Trigger | Key constraint |
|---|---|---|
| `elo-recalculate` | DB Webhook on `match_results.status → confirmed/overridden` | Idempotent (guard on existing elo_history for same match_id); serializable transaction with `SELECT FOR UPDATE` |
| `match-auto-confirm` | Cron every hour | Only touches `status = 'pending'` rows older than 48h |
| `request-expiry` | Cron every hour | Only touches `status = 'pending'` requests past `expires_at` |
| `seed-elo` | HTTP POST after questionnaire insert | **Formula TBD — Q-02** |
| `elo-decay` | Cron daily 02:00 UTC | **Disabled by default — Q-10** |

---

## 6. How the Layers Connect

```
Flutter App
│
├── Supabase.instance.client  ←─ initialized in main.dart with env vars
│   ├── .auth            auth state stream → authStateProvider
│   ├── .from('profiles').select(...)  → currentProfileProvider
│   └── .from('match_results')...     → (screen-level providers, TBD)
│
├── go_router (appRouterProvider)
│   └── watches authStateProvider + currentProfileProvider
│       → auto-redirects on login/logout/questionnaire state change
│
├── Firebase.instance
│   └── firebase_messaging → FCM device token → stored in profiles
│       (token registration TBD in FCM setup task)
│
└── Sentry
    └── wraps runApp → captures all unhandled exceptions + performance traces

Supabase (cloud)
│
├── PostgreSQL
│   ├── Tables (migration 001)
│   ├── Indexes (migration 002)
│   ├── RLS (migration 003)
│   └── Triggers (migration 004)
│
└── Edge Functions (Deno)
    ├── elo-recalculate    ← triggered by DB webhook on match confirm
    ├── match-auto-confirm ← cron hourly
    ├── request-expiry     ← cron hourly
    ├── seed-elo           ← HTTP POST from questionnaire screen
    └── elo-decay          ← cron daily (disabled)
```

---

## 7. First-Run Checklist

```bash
# 1. Install Flutter dependencies + run code generation
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 2. Configure Firebase (FCM)
dart pub global activate flutterfire_cli
flutterfire configure
# → replaces lib/firebase_options.dart with real values

# 3. Set up local Supabase
supabase init         # if not already done
supabase start
supabase db push      # applies migrations 001–005

# 4. Create dev environment file
cp .env.example .env.dev
# Edit .env.dev with real SUPABASE_URL, SUPABASE_ANON_KEY, SENTRY_DSN

# 5. Run on Android
flutter run --dart-define-from-file=.env.dev

# 6. Deploy Edge Functions (when ready)
supabase functions deploy elo-recalculate
supabase functions deploy match-auto-confirm
supabase functions deploy request-expiry
supabase functions deploy seed-elo
```
