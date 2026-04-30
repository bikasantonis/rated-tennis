# RATED — Architecture & Developer Reference

> Last updated: 2026-04-30.
> For a new developer: read this file first, then [ELO_SYSTEM.md](ELO_SYSTEM.md) for rating logic, [DATABASE.md](DATABASE.md) for schema details, [NOTIFICATIONS.md](NOTIFICATIONS.md) for the push pipeline, and [DECISIONS.md](DECISIONS.md) for why key choices were made.

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
   - [Services](#48-services)
5. [supabase/ — Database & Backend](#5-supabase--database--backend)
6. [How the Layers Connect](#6-how-the-layers-connect)
7. [First-Run Checklist](#7-first-run-checklist)

---

## 1. Project Overview

**RATED** is a cross-platform Flutter application providing a universal ELO ranking system for Greek tennis club players. Players receive a profile and initial rating from a sport-history questionnaire; every confirmed match updates both players' ratings via a custom ELO algorithm. The app supports match scheduling, dispute resolution, tournament management with bracket generation, and GDPR-compliant location-based discovery.

| Layer | Technology | Version |
|---|---|---|
| Frontend | Flutter / Dart | ≥ 3.22 |
| State management | Riverpod (code-gen) | 3.1.0 |
| Navigation | go_router (ShellRoute) | 17.1.0 |
| Backend / DB | Supabase (PostgreSQL + PostgREST) | — |
| Auth | Supabase Auth + Google OAuth + Apple Sign-In | — |
| Push notifications | OneSignal | 5.2.5 |
| Error monitoring | Sentry | 9.16.0 |
| Serialisation | Freezed + JSON Serializable | 3.2.3 / 6.8.0 |
| Location | geolocator (GDPR opt-in) | 13.0.0 |
| i18n | Flutter intl | 0.20.2 |

**Target audiences:**
- **Players** — submit and confirm match results, view rankings, join tournaments
- **Organisers** — create and manage tournaments, control brackets
- **Admins** — resolve disputed match results, approve organiser requests

---

## 2. Directory Map

```
rated/
├── lib/
│   ├── main.dart                             Entry point (OneSignal → Supabase → Sentry → runApp)
│   ├── app.dart                              MaterialApp.router + i18n (EN/EL)
│   ├── router/
│   │   └── app_router.dart                  go_router — all routes, redirect logic, transitions
│   ├── theme/
│   │   ├── app_colors.dart                  Design tokens: light/dark + 11 tier colours
│   │   └── app_theme.dart                   MD3 ThemeData + Barlow Condensed / Inter typography
│   ├── models/
│   │   ├── profile.dart                     profiles table + EloTier enum (11 tiers)
│   │   ├── match_result.dart                match_results table + SetScore
│   │   ├── match_request.dart               match_requests table
│   │   ├── tournament.dart                  tournaments table
│   │   ├── elo_history.dart                 elo_history append-only ledger
│   │   ├── notification_item.dart           notifications table (polymorphic reference)
│   │   └── bracket_match.dart               tournament_bracket_matches table
│   ├── providers/
│   │   ├── auth_provider.dart               Session stream + AuthNotifier + currentProfileProvider
│   │   ├── profile_provider.dart            Own/other profile loading + edit + avatar upload
│   │   ├── leaderboard_provider.dart        Global rankings (paginated) + nearbyPlayers
│   │   ├── tournament_provider.dart         Tournaments list/detail + nearbyTournaments + bracket
│   │   ├── match_provider.dart              Match submission/confirmation + friendlyEloExcluded
│   │   ├── location_provider.dart           LocationPrefs + LocationActions (GDPR consent flow)
│   │   ├── organizer_request_provider.dart  Organiser request submit + admin decisions
│   │   ├── questionnaire_provider.dart      Questionnaire submit + seed-elo call
│   │   ├── schedule_match_provider.dart     searchOpponentsProvider (debounced 300 ms)
│   │   ├── locale_provider.dart             Language switching (EN/EL)
│   │   └── notification_panel_provider.dart Real-time notification stream + mark-read
│   ├── services/
│   │   └── notification_service.dart        OneSignal wrapper — identify, clear, deep-link routing
│   ├── widgets/
│   │   ├── bottom_nav_shell.dart            MD3 NavigationBar (4 destinations)
│   │   ├── tier_badge.dart                  Pill badge — colour + label for all 11 tiers
│   │   ├── elo_score_card.dart              Dashboard ELO card (Barlow Condensed 72 pt)
│   │   ├── app_bar_actions.dart             Settings / notifications / profile action icons
│   │   ├── notification_panel.dart          Popup notification list + real-time updates
│   │   ├── tournament_bracket_viewer.dart   Horizontally scrollable single-elimination bracket
│   │   └── pending_badge.dart               CountChip + TabWithBadge for pending-action counts
│   ├── screens/
│   │   ├── splash/                          Branded splash (session restore)
│   │   ├── onboarding/                      SCR-01 — 3-slide intro
│   │   ├── auth/                            SCR-02 — Login + Register (email, Google, Apple)
│   │   ├── questionnaire/                   SCR-03 — Sport-history questionnaire (shown as dialog)
│   │   ├── home/                            SCR-04 — Dashboard + recent matches
│   │   ├── leaderboard/                     SCR-05 — Global rankings + Near Me filter
│   │   ├── profile/                         SCR-06 — Player profile + edit + avatar upload
│   │   ├── match/                           SCR-07/08/09 — Submit / inbox / schedule
│   │   ├── tournament/                      SCR-10/11 — Tournaments list + detail + bracket
│   │   ├── organizer/                       SCR-12 — Organiser dashboard + per-tournament view
│   │   ├── settings/                        SCR-13 — Language, location, account
│   │   └── admin/                           SCR-14 — Dispute resolution + organiser requests
│   ├── l10n/
│   │   ├── app_en.arb                       English strings
│   │   ├── app_el.arb                       Greek strings
│   │   └── app_localizations.dart           Generated localisation class
│   └── gen/                                 flutter_gen generated assets
├── supabase/
│   ├── config.toml                          Local dev stack config
│   ├── migrations/                          21 SQL migrations (applied in order)
│   └── functions/                           6 Deno Edge Functions
├── assets/images/
├── docs/
│   ├── ARCHITECTURE.md                      ← this file
│   ├── ELO_SYSTEM.md                        ELO algorithm, tiers, seed, rules
│   ├── DATABASE.md                          Schema, migrations, triggers, RLS
│   ├── NOTIFICATIONS.md                     Notification types, delivery chain, deep-link routing
│   ├── DECISIONS.md                         Architecture decision records
│   └── TODO.md                              Implementation task tracker
├── test/
├── pubspec.yaml
├── analysis_options.yaml
├── .env.example
└── CHANGELOG.md
```

---

## 3. Root Config Files

### `pubspec.yaml`
Declares all Dart dependencies. Key groups:
- **Supabase** (`supabase_flutter`) — backend, auth, realtime
- **Auth** (`google_sign_in`, `sign_in_with_apple`) — Apple App Store requires both OAuth providers when any is offered
- **Push** (`onesignal_flutter`) — no Firebase dependency; OneSignal handles APNs provisioning automatically
- **State** (`flutter_riverpod`, `riverpod_annotation`) — `@riverpod` code-gen providers
- **Navigation** (`go_router`) — declarative URL routing with deep-link support
- **Models** (`freezed_annotation`, `json_annotation`) — immutable, serialisable data classes
- **Fonts** (`google_fonts`) — Barlow Condensed Bold (ELO numbers) + Inter (body)
- **Charts** (`fl_chart`) — ELO sparkline on player profile
- **Location** (`geolocator`, `http`) — opt-in GDPR GPS + Nominatim reverse geocoding
- **Images** (`image_picker`, `cached_network_image`) — avatar upload + CDN caching

### `analysis_options.yaml`
Enables `custom_lint` + `riverpod_lint` which statically check provider usage — catches incorrect `ref.watch` vs `ref.read` at analysis time, not runtime.

### `.env.example`
Template for three environment files (`.env.dev`, `.env.staging`, `.env.production`). Values are injected at build time via `--dart-define-from-file` so no secrets enter the source tree.

Required keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`, `APP_ENV`, `GOOGLE_CLIENT_ID`, `ONESIGNAL_APP_ID`.

### `.gitignore`
Excludes generated Dart files (`*.freezed.dart`, `*.g.dart`), all `.env.*` files, and platform credentials (`google-services.json`, `GoogleService-Info.plist`) to prevent secret leakage.

---

## 4. lib/ — Flutter Source

### 4.1 Entry Point

#### `lib/main.dart`
Initialises all services in order before `runApp`:

1. **`OneSignal.initialize`** — called with `ONESIGNAL_APP_ID` from `--dart-define-from-file`; `requestPermission(false)` shows the iOS system permission prompt without force-requesting
2. **`NotificationService.instance.init()`** — registers foreground display and tap-routing listeners before the router is ready
3. **`Supabase.initialize`** — uses PKCE auth flow (more secure than implicit on mobile)
4. **`SentryFlutter.init`** — wraps `runApp` so uncaught errors are captured; the app is also wrapped in `ProviderScope` (Riverpod root)

> **No Firebase dependency.** OneSignal handles APNs provisioning automatically via its dashboard. No `google-services.json` or `GoogleService-Info.plist` is required for push.

#### `lib/app.dart`
`RatedApp` is a `ConsumerWidget` reading `appRouterProvider`. `MaterialApp.router` enables go_router declarative navigation. Both `theme` and `darkTheme` are provided from day one (`ThemeMode.system` respects the device setting).

---

### 4.2 Router

#### `lib/router/app_router.dart`

**`AppRoutes` constants** — all path strings in one `abstract final class` to prevent typo-based routing bugs.

**`appRouterProvider`** — a `@riverpod`-annotated `GoRouter` that watches `authProvider` as a `refreshListenable`. The router automatically re-evaluates `redirect` whenever auth state changes.

**Redirect logic:**
1. Splash not yet ready → `/splash` (waits for session restore to complete)
2. Authenticated, arriving at `/splash`, `/onboarding`, or `/login` → `/home`
3. Unauthenticated, not on `/onboarding` or `/login` → `/onboarding`

The questionnaire is **no longer a redirect gate** — it appears as a dialog from `HomeScreen` when `questionnaire_done = false`. The `/questionnaire` route still exists for deep-link compatibility: it shows the dialog immediately and pops when done.

**`ShellRoute`** — wraps the four bottom-nav destinations (`/home`, `/leaderboard`, `/matches`, `/tournaments`) so `BottomNavShell` persists across tabs. Nested routes (e.g. `/leaderboard/:id`) push on top without destroying the shell.

**Role-gated routes** — `/organizer`, `/organizer/tournaments/:id`, `/admin/disputes` are declared in the router but not surfaced in the bottom nav. The organiser dashboard is accessible via a profile overflow menu.

**Transitions:**
- `_slide` — 300 ms `easeInOut` horizontal slide (standard push)
- `_fade` — 350 ms fade (splash and auth screens)

---

### 4.3 Theme

#### `lib/theme/app_colors.dart`
All colour hex values for light and dark modes. Declared as `abstract final class` constants — never instantiated. The 11 tier badge colours are here too, keeping all design tokens auditable in one place.

> **WCAG:** All values were verified at ≥ 4.5:1 contrast ratio. Do not change hex values without re-running contrast checks.

#### `lib/theme/app_theme.dart`
Two `ThemeData` objects (`light`, `dark`) built with `ColorScheme.fromSeed` — MD3 tonal palette derives all 30 colour roles from the seed. Manual overrides only where the design specifies exact values.

Border-radius constants used app-wide:
- `radiusGlobal = 12` — cards, inputs, dialogs
- `radiusPill = 999` — tier badges, chips
- `radiusButton = 20` — MD3 button default

Typography: **Barlow Condensed Bold** for `displayLarge–headlineMedium` (ELO numbers, ranking figures); **Inter** for all body/UI text.

---

### 4.4 Models

All models use **Freezed** for immutability, `copyWith`, equality, and `fromJson`/`toJson`. Run `dart run build_runner build` to regenerate after any changes.

| File | Supabase table | Notable |
|---|---|---|
| `profile.dart` | `profiles` | `EloTier` enum with 11 values (5.0–10.0 at 0.5 intervals); `fromRating()` factory mirrors the `sync_elo_tier` SQL trigger |
| `match_result.dart` | `match_results` | `SetScore` is a nested Freezed class matching the JSONB `score` column structure |
| `match_request.dart` | `match_requests` | `expiresAt` is a generated column in DB (`created_at + 72h`) |
| `tournament.dart` | `tournaments` | `eloMultiplier` range 1.0–1.5 (capped in migration 019) |
| `elo_history.dart` | `elo_history` | Append-only ledger; `delta` is a PostgreSQL generated column |
| `notification_item.dart` | `notifications` | `referenceType` enables polymorphic deep-link routing on tap |
| `bracket_match.dart` | `tournament_bracket_matches` | Slot in a single-elimination bracket (round + position) |

---

### 4.5 Providers

| File | Pattern | Purpose |
|---|---|---|
| `auth_provider.dart` | `ChangeNotifier` + `@riverpod FutureProvider` | Session stream, `AuthStatus`, `currentProfileProvider`. Uses `ChangeNotifier` (not `@riverpod`) because it is passed as `refreshListenable` to `GoRouter`. |
| `profile_provider.dart` | `@riverpod AsyncNotifier` | Own/other profile load, edit, avatar upload/delete |
| `leaderboard_provider.dart` | `@riverpod FutureProvider` | Paginated global rankings; `nearbyPlayersProvider` (location-filtered) |
| `tournament_provider.dart` | `@riverpod FutureProvider` + `AsyncNotifier` | Tournament list/detail, `nearbyTournamentsProvider`, registrations, bracket |
| `match_provider.dart` | `@riverpod AsyncNotifier` | Match submission, confirmation, `friendlyEloExcludedProvider` (tier-gap preview) |
| `location_provider.dart` | `@riverpod AsyncNotifier` | `LocationPrefs` (consent + radius), `LocationActions` (GDPR consent flow) |
| `organizer_request_provider.dart` | `@riverpod FutureProvider` + `AsyncNotifier` | Organiser request submit + admin approve/deny |
| `questionnaire_provider.dart` | `@riverpod AsyncNotifier` | Questionnaire submit → calls `seed-elo` Edge Function |
| `schedule_match_provider.dart` | `@riverpod FutureProvider` | `searchOpponentsProvider` — debounced 300 ms player search |
| `locale_provider.dart` | `@riverpod StateNotifier` | Language switching, persisted to `profiles.preferred_language` |
| `notification_panel_provider.dart` | `@riverpod StreamProvider` + `AsyncNotifier` | Real-time notification stream + mark-as-read |

---

### 4.6 Widgets

| File | Purpose |
|---|---|
| `bottom_nav_shell.dart` | MD3 `NavigationBar` (4 destinations: Home, Leaderboard, Matches, Tournaments). Active tab derived from `matchedLocation.startsWith` so nested routes keep the correct tab highlighted. Uses `context.go()` not `context.push()` to avoid tab stacking. |
| `tier_badge.dart` | Pill-shaped tier badge with correct fill/text colour for all 11 tiers. `Semantics(label: '${tier.label} tier')` for screen readers. `small` flag for compact leaderboard rows. |
| `elo_score_card.dart` | Dashboard ELO card: Barlow Condensed 72 pt rating, tier badge below it, three-stat row (Played / Won / Win%). |
| `app_bar_actions.dart` | Row of icon buttons: settings cog, notification bell (with unread badge), profile avatar. |
| `notification_panel.dart` | Popup overlay listing recent notifications. Streams from `notificationPanelProvider`; marks items as read on open. |
| `tournament_bracket_viewer.dart` | Horizontally scrollable single-elimination bracket. Renders rounds as columns, matches as cards. |
| `pending_badge.dart` | `CountChip` (filled circle with count) and `TabWithBadge` (tab label with inline badge) used throughout the app to show pending-action counts. |

---

### 4.7 Screens

| Screen | File | PRD | Auth | Status |
|---|---|---|---|---|
| Splash | `splash/splash_screen.dart` | — | No | Implemented |
| Onboarding | `onboarding/onboarding_screen.dart` | SCR-01 | No | Implemented |
| Login / Register | `auth/login_screen.dart` | SCR-02 | No | Email + Google + Apple wired |
| Questionnaire | `questionnaire/questionnaire_screen.dart` | SCR-03 | Yes | Dialog; seed-ELO call wired |
| Home / Dashboard | `home/home_screen.dart` | SCR-04 | Yes | EloScoreCard + recent matches |
| Leaderboard | `leaderboard/leaderboard_screen.dart` | SCR-05 | Yes | Paginated query + Near Me filter |
| Player Profile | `profile/profile_screen.dart` | SCR-06 | Yes | Avatar upload, extended stats, tier progress bar |
| Submit Match | `match/submit_match_screen.dart` | SCR-07 | Yes | Score entry + validation wired |
| Match Inbox | `match/match_inbox_screen.dart` | SCR-08 | Yes | Confirm / dispute / request tabs wired |
| Schedule Match | `match/schedule_match_screen.dart` | SCR-09 | Yes | Debounced opponent search wired |
| Tournaments List | `tournament/tournaments_list_screen.dart` | SCR-10 | Yes | Open / Registered / Past / Near Me tabs |
| Tournament Detail | `tournament/tournament_detail_screen.dart` | SCR-11 | Yes | Info / Participants / Bracket tabs; bracket viewer wired |
| Organiser Dashboard | `organizer/organizer_dashboard_screen.dart` | SCR-12 | Organiser+ | Per-tournament management screen |
| Organiser Tournament | `organizer/organizer_tournament_detail_screen.dart` | SCR-12b | Organiser+ | Per-tournament detail and controls |
| Settings | `settings/settings_screen.dart` | SCR-13 | Yes | Language, location consent, account |
| Admin Panel | `admin/dispute_resolution_screen.dart` | SCR-14 | Admin | Dispute resolution + organiser request review |

---

### 4.8 Services

#### `lib/services/notification_service.dart`
Singleton (`NotificationService.instance`) wrapping all OneSignal interactions:
- **`init()`** — registers foreground display listener (shows push as in-app banner) and tap click listener
- **`identifyUser(supabaseUserId)`** — calls `OneSignal.login(uid)` to link the device to the authenticated user
- **`clearUser()`** — calls `OneSignal.logout()` on sign-out so the device is no longer targeted
- **`resolveRoute(referenceType, referenceId)`** — maps a notification payload pair to a go_router path; also used by the in-app `notification_panel.dart` on tile tap

See [NOTIFICATIONS.md](NOTIFICATIONS.md) for the full routing table and delivery pipeline.

---

## 5. supabase/ — Database & Backend

See [DATABASE.md](DATABASE.md) for the full schema, 21-migration log, triggers, helper functions, and RLS policies.

**Edge Functions (Deno):**

| Function | Trigger | Purpose |
|---|---|---|
| `elo-recalculate` | HTTP POST from Flutter (match confirm button) | Validates caller is non-submitter; sets match `confirmed`; calls `apply_elo_changes` RPC |
| `send-notification` | DB webhook on `notifications INSERT` | Looks up recipient, POSTs to OneSignal REST API |
| `send-email` | DB webhook on `organizer_requests` change | Sends transactional email via Resend |
| `notify-nearby-tournament` | Called when tournament `registration_open` → true | Queries `nearby_tournament_notify_targets()`, sends push to each matched player |
| `anonymise-account` | HTTP POST from Flutter (account deletion) | GDPR Art. 17 — NULLs PII and location data, soft-deletes profile |
| `seed-elo` | HTTP POST from Flutter (questionnaire submit) | Computes initial ELO from sport-history questionnaire, updates profile |

See [ELO_SYSTEM.md](ELO_SYSTEM.md) for the full rating algorithm.

---

## 6. How the Layers Connect

```
Flutter App
│
├── Supabase.instance.client  ←── initialised in main.dart with env vars
│   ├── .auth.onAuthStateChange  →  authProvider (ChangeNotifier)
│   ├── .from('profiles')        →  currentProfileProvider, profileProvider
│   ├── .from('notifications')   →  notificationPanelProvider (realtime stream)
│   └── .rpc() / .from(...)      →  match, tournament, leaderboard providers
│
├── go_router (appRouterProvider)
│   └── refreshListenable: authProvider
│       → auto-redirects on sign-in / sign-out
│
├── NotificationService (OneSignal)
│   ├── identifyUser(uid)              → links device to Supabase user
│   ├── foregroundWillDisplayListener  → shows in-app banner
│   └── clickListener                  → resolveRoute() → router.push(path)
│
└── Sentry
    └── wraps runApp → captures unhandled exceptions + performance traces

Supabase (cloud)
│
├── PostgreSQL
│   ├── 21 migrations (schema, indexes, RLS, triggers, functions)
│   ├── pg_cron jobs (match-auto-confirm, request-expiry — hourly)
│   └── DB webhooks → Edge Functions on table events
│
└── Edge Functions (Deno)
    ├── elo-recalculate          ← HTTP POST from Flutter on confirm
    ├── send-notification        ← DB webhook on notifications INSERT
    ├── send-email               ← DB webhook on organizer_requests change
    ├── notify-nearby-tournament ← called on registration_open event
    ├── anonymise-account        ← HTTP POST from Flutter on account delete
    └── seed-elo                 ← HTTP POST from Flutter after questionnaire
```

---

## 7. First-Run Checklist

```bash
# 1. Install Flutter dependencies + run code generation
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 2. Set up local Supabase
supabase start
supabase db push      # applies all 21 migrations in order

# 3. Create dev environment file
cp .env.example .env.dev
# Edit .env.dev: SUPABASE_URL, SUPABASE_ANON_KEY, ONESIGNAL_APP_ID, SENTRY_DSN, GOOGLE_CLIENT_ID

# 4. Run on device / emulator
flutter run --dart-define-from-file=.env.dev

# 5. Run on web (required for Google OAuth redirect to work)
flutter run -d chrome --dart-define-from-file=.env.dev --web-port=3000

# 6. Deploy Edge Functions
supabase functions deploy elo-recalculate
supabase functions deploy send-notification
supabase functions deploy send-email
supabase functions deploy notify-nearby-tournament
supabase functions deploy anonymise-account
supabase functions deploy seed-elo
```
