# RATED — Architecture & Developer Reference

> Last updated: 2026-09-14 (post-launch). The web app is live at **https://ratedtennis.gr**; production Supabase is at migration **028**.
> For a new developer: read this file first, then [ELO_SYSTEM.md](ELO_SYSTEM.md) for rating logic, [DATABASE.md](DATABASE.md) for the schema and the migration workflow, [NOTIFICATIONS.md](NOTIFICATIONS.md) for the push/email pipeline, [DECISIONS.md](DECISIONS.md) for why key choices were made, and [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) before shipping anything.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Environments & Hosting](#2-environments--hosting)
3. [Directory Map](#3-directory-map)
4. [Root Config Files](#4-root-config-files)
5. [lib/ — Flutter Source](#5-lib--flutter-source)
6. [supabase/ — Database & Backend](#6-supabase--database--backend)
7. [How the Layers Connect](#7-how-the-layers-connect)
8. [First-Run Checklist](#8-first-run-checklist)

---

## 1. Project Overview

**RATED** is a cross-platform Flutter application providing a universal ELO ranking system for Greek tennis club players. Players receive a profile and initial rating from a sport-history questionnaire; every confirmed match updates both players' ratings via a custom ELO algorithm. The app supports match scheduling ("challenges"), dispute resolution, tournament management with bracket generation, and GDPR-compliant location-based discovery.

| Layer | Technology | Version |
|---|---|---|
| Frontend | Flutter / Dart | Dart ≥ 3.8; CI pins Flutter 3.38.5 |
| State management | Riverpod (code-gen) | flutter_riverpod 3.1 / riverpod_annotation 4.0 |
| Navigation | go_router (ShellRoute) | 17.1 |
| Backend / DB | Supabase (PostgreSQL 17 + PostgREST + Realtime) | supabase_flutter 2.5 |
| Auth | Supabase Auth — email/password, Google (OAuth redirect), Apple (native ID token) | — |
| Push notifications | OneSignal — **native only**, no web push | 5.2.5 |
| Transactional email | Resend (via the `send-email` Edge Function) | — |
| Error monitoring | Sentry | 9.16 |
| Serialisation | Freezed + JSON Serializable | 3.2.3 / 6.8.0 |
| Location | geolocator (GDPR opt-in) + Nominatim reverse geocoding | 13.0 |
| i18n | Flutter intl (EN / EL) | 0.20.2 |
| Web hosting | Cloudflare Pages | — |

**Platforms:** Android and iOS (application ID `com.rated.app`), and web (`ratedtennis.gr`). App version in `pubspec.yaml`: `1.0.0+1`.

**Target audiences:**
- **Players** — submit and confirm match results, challenge opponents, view rankings, join tournaments
- **Organisers** — create and manage tournaments, control brackets
- **Admins** — resolve disputed match results, approve organiser requests

---

## 2. Environments & Hosting

### Supabase environments

| Environment | Supabase project | Region | Flutter env file | How schema changes arrive |
|---|---|---|---|---|
| **Local** | Docker stack from `supabase start` | — | `.env.local` (`APP_ENV=local`) | `supabase start` / `supabase db reset` replay every migration from empty, then `supabase/seed.sql` |
| **DEV** | `ikjdfsjflzwkhlbootbx` ("RATED Dev") | eu-central-1 (Frankfurt) | `.env.dev` | `supabase db push` — the CLI's default link |
| **PROD** | `jkjndgcjyalmglnvvdrd` ("Rated PROD") | eu-west-1 (Ireland) | `.env.production` (`APP_ENV=production`) | `./scripts/push-prod.ps1` only |

- There is **no separate staging project** — DEV plays that role. `.env.staging` still appears in `.gitignore` and the `.env.example` header, but no such file or project exists.
- The CLI is linked to **DEV** (`supabase/.temp/project-ref`, gitignored) so every linked command is safe by default. Never `supabase link` to PROD by hand — the push script links PROD, applies, and relinks DEV in a `finally` block. See [DATABASE.md §7](DATABASE.md#7-applying-migrations) for the full workflow.
- **Local stack** (`supabase/config.toml`): API `http://127.0.0.1:54321`, DB `54322`, Studio `http://127.0.0.1:54323`, Mailpit (auth emails) `http://127.0.0.1:54324`. Postgres 17 to match PROD (17.6). Analytics is disabled (heavy, unreliable on Windows). Google/Apple OAuth are disabled and email confirmations are off, so use the seed accounts `alice@rated.test` / `bob@rated.test` (password `password123`). Database Webhooks do not exist locally, so notification rows are created but no push or email is sent.
- **Per-project configuration that `db push` does not carry:** Edge Function deploys, function secrets, Database Webhooks, and Auth providers / redirect URLs. As of 2026-09-13 these had not been verified on DEV.

### Web hosting

- **Cloudflare Pages** project `ratedtennis`, production branch `main`, published by **direct upload**. Cloudflare's build image has no Flutter SDK, so the bundle is built locally:
  ```bash
  flutter build web --dart-define-from-file=.env.production
  wrangler pages deploy build/web --branch=main
  ```
- `ratedtennis.gr` is the canonical custom domain (Cloudflare-managed TLS, apex CNAME → `ratedtennis.pages.dev`). `ratedtennis.com` (apex and `www`) 301-redirects to `https://ratedtennis.gr` via a Cloudflare Redirect Rule, preserving path and query string.
- Both domains are in the Edge Function CORS allowlist (`supabase/functions/_shared/cors.ts`) alongside `localhost:3000` and `localhost:8080`. Unknown origins get an empty `Access-Control-Allow-Origin`.
- The Privacy Policy and Terms of Use (`docs/privacy-policy.html`, `docs/terms.html`) are served by GitHub Pages at `bikasantonis.github.io/rated-tennis/` — URLs live in `lib/utils/legal_urls.dart`.

### Monitoring

**Sentry** — one project for all environments; events are tagged with `APP_ENV` through `options.environment`, and `tracesSampleRate` is 0.2. `.env.local` leaves `SENTRY_DSN` blank so local runs never report.

### CI

Two GitHub Actions workflows run on every PR to `main` and every push to `main` (Flutter 3.38.5):

| Workflow | Steps |
|---|---|
| `pr.yml` ("PR checks") | `build_runner`, `flutter gen-l10n`, `flutter analyze --fatal-warnings`, `flutter test test/models/`, debug APK build |
| `ci.yml` ("CI") | `build_runner`, `flutter analyze`, `flutter build web` (dart-defines from repository secrets), `flutter test` |

No workflow deploys anything — Supabase migrations, Edge Functions, and the Cloudflare upload are manual (see [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)).

---

## 3. Directory Map

```
rated/
├── lib/
│   ├── main.dart                             Entry point (Sentry zone → OneSignal [native] → Supabase → runApp)
│   ├── app.dart                              MaterialApp.router + i18n (EN/EL)
│   ├── router/
│   │   └── app_router.dart                  go_router — all routes, redirect logic, transitions
│   ├── theme/
│   │   ├── app_colors.dart                  Design tokens: light/dark surfaces, 11 tier colours, 4 Grand Slam palettes
│   │   └── app_theme.dart                   MD3 ThemeData + Barlow Condensed / IBM Plex Sans typography
│   ├── models/
│   │   ├── profile.dart                     profiles table + EloTier enum (11 tiers)
│   │   ├── match_result.dart                match_results table + SetScore
│   │   ├── match_validation.dart            Score / match-format validation (unit-tested)
│   │   ├── match_request.dart               match_requests table ("challenges")
│   │   ├── tournament.dart                  tournaments table
│   │   ├── bracket_match.dart               tournament_bracket_matches table
│   │   ├── elo_history.dart                 elo_history append-only ledger
│   │   ├── notification_item.dart           notifications table (polymorphic reference)
│   │   └── court_theme.dart                 CourtTheme enum — 5 EloScoreCard court backgrounds
│   ├── providers/
│   │   ├── auth_provider.dart               AuthChangeNotifier + session stream + currentProfile + AuthActions
│   │   ├── profile_provider.dart            Profile, ELO history, match history, rank, edit + avatar upload
│   │   ├── leaderboard_provider.dart        get_leaderboard_page RPC (50/page, club filter) + nearbyPlayers + clubs
│   │   ├── tournament_provider.dart         Tournaments, registrations, bracket, TournamentActions, DisputeActions
│   │   ├── match_provider.dart              Feed, inbox queries, MatchActions (keepAlive), friendlyEloExcluded
│   │   ├── schedule_match_provider.dart     browsePlayers (ELO-range browse) + ScheduleMatchActions
│   │   ├── location_provider.dart           LocationPrefs + LocationActions (GDPR consent flow)
│   │   ├── organizer_request_provider.dart  Organiser request submit + admin decisions
│   │   ├── questionnaire_provider.dart      Questionnaire submit → seed-elo Edge Function
│   │   ├── questionnaire_prompt_provider.dart One-time questionnaire prompt flag (shared_preferences)
│   │   ├── court_theme_provider.dart        Current CourtTheme derived from the profile
│   │   ├── locale_provider.dart             Language switching (EN/EL)
│   │   ├── realtime_sync_provider.dart      Per-user Realtime channel → refreshes match / profile / inbox providers
│   │   └── notification_panel_provider.dart Real-time notification stream + mark-read
│   ├── services/
│   │   └── notification_service.dart        OneSignal wrapper — identify, clear, deep-link routing
│   ├── utils/
│   │   ├── legal_urls.dart                  Privacy Policy / Terms URLs + open helper
│   │   ├── streak_utils.dart                computeWinStreak() — shared win/loss streak helper
│   │   └── tier_path_calculator.dart        Client-side "path to next tier" suggestion (same formula as the DB)
│   ├── widgets/                             Shared widgets — see §5.6
│   ├── screens/
│   │   ├── splash/                          Branded splash (session restore)
│   │   ├── onboarding/                      SCR-01 — intro slides with the login/register panel embedded
│   │   ├── auth/                            SCR-02 — Login + Register (email, Google, Apple)
│   │   ├── questionnaire/                   SCR-03 — Sport-history questionnaire (shown as dialog)
│   │   ├── home/                            SCR-04 — Dashboard + recent matches
│   │   ├── leaderboard/                     SCR-05 — Global rankings + club filter + Near Me
│   │   ├── profile/                         SCR-06 — Player profile + edit + avatar upload
│   │   ├── match/                           SCR-07/08/09 — Submit / inbox / schedule (challenge)
│   │   ├── tournament/                      SCR-10/11 — Tournaments list + detail + bracket
│   │   ├── organizer/                       SCR-12 — Organiser dashboard + per-tournament view
│   │   ├── settings/                        SCR-13 — Language, appearance, location, legal, account
│   │   └── admin/                           SCR-14 — Dispute resolution + organiser requests
│   ├── l10n/                                app_en.arb, app_el.arb + generated AppLocalizations
│   └── gen/                                 flutter_gen generated assets (gitignored)
├── supabase/
│   ├── config.toml                          Local Docker stack config (ports, Postgres 17, auth)
│   ├── migrations/                          28 SQL migrations, 001–029 (012 intentionally missing)
│   ├── seed.sql                             Local-only seed: 2 test accounts + 2 matches
│   └── functions/                           6 Deno Edge Functions + _shared/cors.ts
├── scripts/
│   └── push-prod.ps1                        The only sanctioned route to PROD (migrations + optional functions)
├── .github/workflows/                       pr.yml, ci.yml
├── docs/
│   ├── ARCHITECTURE.md                      ← this file
│   ├── ELO_SYSTEM.md                        ELO algorithm, tiers, seed, rules
│   ├── DATABASE.md                          Schema, migrations, triggers, RLS, migration workflow
│   ├── NOTIFICATIONS.md                     Notification types, delivery chain, deep-link routing
│   ├── DECISIONS.md                         Architecture decision records
│   ├── DEPLOYMENT_CHECKLIST.md              Release checklist + launch status
│   ├── TODO.md                              Post-launch backlog
│   ├── privacy-policy.html / terms.html     Legal pages (served via GitHub Pages)
│   └── figma/                               Design references and tokens
├── test/                                    models/ (EloTier, match validation, Profile) + widget_test.dart
├── android/ ios/ web/                       Platform projects (web/ holds index.html metadata + manifest)
├── pubspec.yaml
├── analysis_options.yaml
├── .env.example
└── CHANGELOG.md
```

---

## 4. Root Config Files

### `pubspec.yaml`
Declares all Dart dependencies. Key groups:
- **Supabase** (`supabase_flutter`) — backend, auth, realtime, Edge Function calls
- **Auth** (`sign_in_with_apple`) — Apple Sign-In on iOS/Android. Google Sign-In uses Supabase's OAuth redirect (`signInWithOAuth`), so there is no `google_sign_in` dependency.
- **Push** (`onesignal_flutter`) — no Firebase dependency; OneSignal handles APNs/FCM
- **State** (`flutter_riverpod`, `riverpod_annotation`) — `@riverpod` code-gen providers
- **Navigation** (`go_router`) — declarative URL routing with deep-link support
- **Models** (`freezed_annotation`, `json_annotation`) — immutable, serialisable data classes
- **Fonts** (`google_fonts`) — Barlow Condensed Bold (ELO numbers/headings) + IBM Plex Sans (body/labels)
- **Charts** (`fl_chart`) — ELO sparkline on the home card and player profile
- **Celebration** (`confetti`) — match-win confetti burst on the home screen
- **Location** (`geolocator`, `http`) — opt-in GPS + Nominatim reverse geocoding
- **Images** (`image_picker`, `cached_network_image`, `flutter_cache_manager`) — avatar upload + caching
- **Persistence** (`shared_preferences`) — questionnaire-prompt flag and similar device-local state
- **Links** (`url_launcher`) — opens the legal documents in the browser
- `flutter_secure_storage` is declared but not currently used (see TODO.md)

### `analysis_options.yaml`
Enables `custom_lint` + `riverpod_lint`, which statically check provider usage — catches incorrect `ref.watch` vs `ref.read` at analysis time, not runtime.

### `.env.example` and the env files
Template for the per-environment files (`.env.local`, `.env.dev`, `.env.production` — see §2). Values are injected at build time via `--dart-define-from-file`, so no secrets enter the source tree.

Keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`, `APP_ENV`, `GOOGLE_CLIENT_ID`, `ONESIGNAL_APP_ID`. In `.env.local`, `SUPABASE_URL` is `http://127.0.0.1:54321` (an Android emulator needs `http://10.0.2.2:54321`) and the anon key comes from `supabase status`; Sentry, OneSignal and Google values stay blank.

### `.gitignore`
Excludes all env files (`.env.local`, `.env.dev`, `.env.staging`, `.env.production`, `*.env`, `dart_defines*.json`), Android signing material (`key.properties`, `*.jks`, `*.keystore`), generated Dart (`*.freezed.dart`, `*.g.dart`, `lib/gen/`), Supabase CLI state (`.temp`, `.branches`), the Wrangler cache (`.wrangler/`), and platform credentials (`google-services.json`, `GoogleService-Info.plist`).

### Android release build
`android/app/build.gradle.kts` reads signing credentials from `android/app/key.properties` (gitignored; template with `keytool` instructions in `key.properties.template`) and falls back to debug keys when it is absent. Release builds enable R8 minification and resource shrinking (`proguard-rules.pro`). The OAuth deep-link scheme is `io.supabase.rated://login-callback`.

---

## 5. lib/ — Flutter Source

### 5.1 Entry Point

#### `lib/main.dart`
Initialisation order:

1. **`SentryFlutter.init`** — wraps everything. DSN and environment come from `SENTRY_DSN` / `APP_ENV`; `tracesSampleRate = 0.2`. All other initialisation runs inside its `appRunner`, so uncaught errors are captured.
2. **`WidgetsFlutterBinding.ensureInitialized()`**
3. **OneSignal (native only, skipped on web)** — `OneSignal.initialize(ONESIGNAL_APP_ID)`, `requestPermission(false)`, then `NotificationService.instance.init()` registers the foreground and tap listeners.
4. **`Supabase.initialize`** — PKCE auth flow.
5. **`runApp(ProviderScope(child: RatedApp()))`**

> **No Firebase dependency.** OneSignal handles APNs provisioning via its dashboard. No `google-services.json` or `GoogleService-Info.plist` is required for push.

#### `lib/app.dart`
`RatedApp` is a `ConsumerWidget` reading `appRouterProvider`. It also watches `realtimeSyncProvider`, which keeps the signed-in user's Realtime channel open for the whole session. `MaterialApp.router` enables go_router declarative navigation. Both `theme` and `darkTheme` are provided (`ThemeMode.system` follows the device setting).

---

### 5.2 Router

#### `lib/router/app_router.dart`

**`AppRoutes` constants** — all path strings in one `abstract final class` to prevent typo-based routing bugs.

**`appRouterProvider`** — the `GoRouter` is created once and uses `AuthChangeNotifier` as its `refreshListenable`, so `redirect` re-evaluates on every auth change without rebuilding the router. `debugLogDiagnostics` is on only in debug builds.

**Redirect logic:**
1. Splash not yet ready → `/splash` (waits for session restore)
2. Authenticated, arriving at `/splash`, `/onboarding`, or `/login` → `/home`
3. Unauthenticated, not on `/onboarding` or `/login` → `/onboarding`

The questionnaire is **not a redirect gate** — it appears as a dialog from `HomeScreen` when `questionnaire_done = false` (once per user, tracked by `questionnaire_prompt_provider`). The `/questionnaire` route still exists for deep-link compatibility.

**`ShellRoute`** — wraps the four bottom-nav destinations (`/home`, `/leaderboard`, `/matches`, `/tournaments`) so `BottomNavShell` persists across tabs. Nested routes push on top of the shell: `/leaderboard/:id` (another player's profile) and `/tournaments/:id`.

**Other routes:** `/profile`, `/matches/submit`, `/matches/schedule`, `/settings`, and the role-gated `/organizer`, `/organizer/tournaments/:id`, `/admin/disputes`. The role-gated screens are reached from app-bar icons — a trophy for organisers/admins and a shield for admins — not from the bottom nav.

**Transitions:**
- `_slide` — 300 ms `easeInOut` horizontal slide (standard push)
- `_fade` — 350 ms fade (splash and auth screens)

---

### 5.3 Theme

#### `lib/theme/app_colors.dart`
All colour hex values for light and dark modes, declared as `abstract final class` constants. The 11 tier badge colours live here too, keeping all design tokens auditable in one place.

> **WCAG:** All values were verified at ≥ 4.5:1 contrast ratio. Do not change hex values without re-running contrast checks.

#### `lib/theme/app_theme.dart`
Two `ThemeData` objects (`light`, `dark`) built with `ColorScheme.fromSeed`; manual overrides only where the design specifies exact values.

Border-radius constants used app-wide:
- `radiusGlobal = 12` — cards, inputs, dialogs
- `radiusPill = 999` — tier badges, chips
- `radiusButton = 20` — MD3 button default

Typography: **Barlow Condensed Bold** for `displayLarge–headlineMedium` (ELO numbers, ranking figures); **IBM Plex Sans** for all body/UI text.

**Grand Slam colour palette** — each bottom-nav section carries a slam-specific accent, in tennis-calendar order:

| Tab | Slam | Primary accent | Secondary accent |
|---|---|---|---|
| 0 — Home | Australian Open | `#006EA7` (hard-court blue) | `#F4C430` (gold) |
| 1 — Leaderboard | Roland Garros | `#C8440F` (clay) | `#3D6B35` (olive) |
| 2 — Matches | Wimbledon | `#006B3C` (grass green) | `#5B2D8E` (purple) |
| 3 — Tournaments | US Open | `#002D72` (asphalt navy) | `#F7A800` (gold) |

Use `AppColors.slamAccent(tabIndex)` / `AppColors.slamSecondary(tabIndex)` to resolve the correct colour.

**Dark mode surfaces:** background `#0A0F1E`, card `#101829`, elevated surface `#141E30`. Brand primary (web `theme_color`) is `#1B4F8A`.

---

### 5.4 Models

All table models use **Freezed** for immutability, `copyWith`, equality, and `fromJson`/`toJson`. Run `dart run build_runner build --delete-conflicting-outputs` after any change — generated files are gitignored.

| File | Supabase table | Notable |
|---|---|---|
| `profile.dart` | `profiles` | `EloTier` enum with 11 values (5.0–10.0 at 0.5 intervals), mirroring the `sync_elo_tier` SQL trigger |
| `match_result.dart` | `match_results` | `SetScore` matches the JSONB `score` column structure |
| `match_validation.dart` | — | Score and match-format validation used by Submit Match; covered by `test/models/match_validation_test.dart` |
| `match_request.dart` | `match_requests` | `expiresAt` defaults to `now() + 72h` in the DB |
| `tournament.dart` | `tournaments` | `eloMultiplier` range 1.0–1.5 (capped in migration 019) |
| `bracket_match.dart` | `tournament_bracket_matches` | One single-elimination slot (`round_number` + `match_number`, `is_bye`) |
| `elo_history.dart` | `elo_history` | Append-only ledger; `delta` is a PostgreSQL generated column |
| `notification_item.dart` | `notifications` | `referenceType` enables polymorphic deep-link routing on tap |
| `court_theme.dart` | — | 5 court backgrounds; persisted as `profiles.court_theme` |

---

### 5.5 Providers

| File | Contents |
|---|---|
| `auth_provider.dart` | `AuthChangeNotifier` (a `ChangeNotifier`, because GoRouter's `refreshListenable` needs a `Listenable`), `authState` session stream, `currentProfile`, and `AuthActions`: email sign-in/up (GDPR consent timestamp stored as `gdpr_consent_at` in the auth user metadata), Google, Apple, reset/change password, `anonymiseAccount` |
| `profile_provider.dart` | Profile loading, `eloHistory`, `playerMatches` (settled = `confirmed` or `overridden`), questionnaire answers, tournament history, `playerGlobalRank`, `ProfileEditActions` (edit, avatar upload/delete) |
| `leaderboard_provider.dart` | `leaderboardPage` via the `get_leaderboard_page` RPC (50 per page, optional club filter, server-computed `global_rank`), `nearbyPlayers`, `clubs` |
| `tournament_provider.dart` | Tournament lists (incl. `nearbyTournaments`, `myTournaments`), registrations, `bracketMatches`, `TournamentActions` (lifecycle, `generateBracket` — ELO-seeded single elimination with byes, `recordBracketResult`), `disputedMatches` + `DisputeActions` (approve / override, then `apply_elo_changes` RPC) |
| `match_provider.dart` | `searchOpponents`, `recentMatches`, `pendingResults`, `pendingRequests`, `invalidateMatchViews` (the shared refresh set, used by `MatchActions` and `realtimeSync`), `MatchActions` (`keepAlive` so invalidation survives leaving the inbox; confirm calls the `elo-recalculate` Edge Function), `friendlyEloExcluded` (tier-gap preview) |
| `schedule_match_provider.dart` | `browsePlayers` (ELO-range browse) + `ScheduleMatchActions` (send a challenge) |
| `location_provider.dart` | `locationPrefs` (consent + radius) and `LocationActions` (GDPR consent flow, ~1 km rounding, Nominatim) |
| `organizer_request_provider.dart` | Own request, `pendingOrganizerRequests`, `OrganizerRequestActions` |
| `questionnaire_provider.dart` | `QuestionnaireActions` → `seed-elo` Edge Function |
| `questionnaire_prompt_provider.dart` | Plain `FutureProvider.family` — whether the one-time questionnaire prompt was already shown for a user |
| `court_theme_provider.dart` | Plain `Provider<CourtTheme>` derived from `currentProfile.courtTheme` |
| `locale_provider.dart` | `savedLocale` + `LocaleNotifier`, persisted to `profiles.preferred_language` |
| `notification_panel_provider.dart` | Realtime notification stream + `NotificationActions` (mark-as-read) |
| `realtime_sync_provider.dart` | `realtimeSync` (`keepAlive`, rebuilt on sign-in / sign-out): one `user-sync:<uid>` channel with Postgres Changes on the user's own `profiles` row, `match_results` as winner and as loser (filters cannot OR), and `match_requests` as recipient. Events are signals only — payloads are ignored; a 300 ms debounce coalesces a burst (one confirmation fires three events) into one `invalidateMatchViews` / `pendingRequests` refresh, and every re-subscribe after a disconnect refetches everything because missed events are not replayed. Needs migration 029 |

After a match is submitted, confirmed, or a dispute resolved, the actions invalidate the match feed, inbox, profile, rating and sparkline providers centrally, so Home updates without a manual refresh.

---

### 5.6 Widgets

| File | Purpose |
|---|---|
| `bottom_nav_shell.dart` | MD3 `NavigationBar` (Home, Leaderboard, Matches, Tournaments). Active tab derived from `matchedLocation.startsWith`, so nested routes keep the right tab highlighted. Per-tab slam accent. Uses `context.go()` to avoid tab stacking. |
| `tier_badge.dart` | Pill-shaped tier badge for all 11 tiers, with a screen-reader `Semantics` label. `small` flag for compact leaderboard rows. |
| `elo_score_card.dart` | Home ELO card: Barlow Condensed 72 pt rating, win-streak badge, tier badge + tier-info button, Played / Won / Win % stats, sparkline, tier progress bar. In court-theme mode, content is positioned inside the painted court zones using a fixed 1.214 : 1 aspect ratio. |
| `court_painter.dart` | `CustomPainter` drawing the top-down court backgrounds (Australian Open, Roland Garros, Wimbledon, US Open, Club Classic). |
| `tier_info_button.dart` | ⓘ popup (hover on web/desktop, tap on mobile) with the points remaining to the next tier and a suggested path from `tier_path_calculator.dart`. Hidden at tier 10.0. |
| `elo_sparkline.dart` | `fl_chart` line of the last 10 ELO history points; renders nothing with fewer than 2 points. |
| `tier_progress_bar.dart` | Progress from the current tier threshold to the next, flanked by `TierBadge`s. |
| `win_streak_badge.dart` | Flame 🔥 + count pill for streaks ≥ 2. |
| `not_rated_chip.dart` | "Not rated" chip (with long-press reason) shown in place of the ELO delta for ELO-excluded friendlies. |
| `error_state_widget.dart` | Shared error state (icon, localised message, optional retry). Used instead of raw `Text('Error: $e')`. |
| `app_bar_actions.dart` | App-bar icons: settings, notifications (unread badge), organiser trophy / admin shield (role-dependent, with pending counts), profile. |
| `notification_panel.dart` | Popup notification list with realtime updates; tile tap routes via `NotificationService.resolveRoute`. |
| `tournament_bracket_viewer.dart` | Horizontally scrollable single-elimination bracket. |
| `pending_badge.dart` | `CountChip` and `TabWithBadge` for pending-action counts. |

---

### 5.7 Screens

| Screen | File | PRD | Access | Notes |
|---|---|---|---|---|
| Splash | `splash/splash_screen.dart` | — | Public | Session restore |
| Onboarding + Auth | `onboarding/onboarding_screen.dart` | SCR-01 | Public | Slides with the login/register panel always visible |
| Login / Register | `auth/login_screen.dart` | SCR-02 | Public | Email + Google + Apple (native); consent checkbox with legal links; Google data-disclosure sheet; forgot password |
| Questionnaire | `questionnaire/questionnaire_screen.dart` | SCR-03 | Signed in | Dialog; calls `seed-elo` |
| Home / Dashboard | `home/home_screen.dart` | SCR-04 | Signed in | EloScoreCard + last 5 settled matches with ELO delta / Not rated chip |
| Leaderboard | `leaderboard/leaderboard_screen.dart` | SCR-05 | Signed in | Paginated RPC, club filter, Near Me; row tap → `/leaderboard/:id` |
| Player Profile | `profile/profile_screen.dart` | SCR-06 | Signed in | Avatar upload, extended stats, match + tournament history |
| Submit Match | `match/submit_match_screen.dart` | SCR-07 | Signed in | Score entry + format validation |
| Match Inbox | `match/match_inbox_screen.dart` | SCR-08 | Signed in | To Confirm / Challenges tabs; confirm shows a spinner until the list refreshes |
| Schedule Match | `match/schedule_match_screen.dart` | SCR-09 | Signed in | ELO-range browse + debounced name search; max-gain preview |
| Tournaments List | `tournament/tournaments_list_screen.dart` | SCR-10 | Signed in | Near Me / Upcoming / Registered / Past tabs |
| Tournament Detail | `tournament/tournament_detail_screen.dart` | SCR-11 | Signed in | Info / Participants / Bracket |
| Organiser Dashboard | `organizer/organizer_dashboard_screen.dart` | SCR-12 | Organiser+ | Drafts / Upcoming / In Progress / Completed; create tournament |
| Organiser Tournament | `organizer/organizer_tournament_detail_screen.dart` | SCR-12b | Organiser+ | Registrations / Status Controls / Bracket |
| Settings | `settings/settings_screen.dart` | SCR-13 | Signed in | Language, appearance (court theme), location consent, legal, change password, delete account, organiser request |
| Admin Panel | `admin/dispute_resolution_screen.dart` | SCR-14 | Admin | Match disputes + organiser requests |

---

### 5.8 Services

#### `lib/services/notification_service.dart`
Singleton (`NotificationService.instance`) wrapping all OneSignal interactions:
- **`init()`** — foreground display listener and tap listener (native only; not called on web)
- **`identifyUser(supabaseUserId)`** — `OneSignal.login(uid)`; no-op on web
- **`clearUser()`** — `OneSignal.logout()` on sign-out; no-op on web
- **`resolveRoute(referenceType, referenceId)`** — maps a notification payload to a go_router path; also used by the in-app panel

See [NOTIFICATIONS.md](NOTIFICATIONS.md) for the routing table and delivery pipeline.

---

## 6. supabase/ — Database & Backend

See [DATABASE.md](DATABASE.md) for the full schema, migration log, triggers, helper functions, RLS policies, and the local → dev → prod workflow.

**Edge Functions (Deno):**

| Function | Invoked by | Purpose |
|---|---|---|
| `elo-recalculate` | Flutter `functions.invoke` when the opponent taps Confirm (user JWT) | Verifies the caller is the non-submitting participant and the match is `pending`; sets `confirmed`; calls `apply_elo_changes` |
| `seed-elo` | Flutter, on questionnaire submit | Validates input (age 16–90, conditional sub-fields), computes the seed rating, upserts `questionnaire_responses`, updates the profile |
| `anonymise-account` | Flutter, Settings → Delete account | Scrubs profile PII and location, deletes `questionnaire_responses`, deletes the auth user. **Known issue:** see [DATABASE.md §8](DATABASE.md#8-known-issues) |
| `send-notification` | Database Webhook: `notifications` INSERT | Pushes via the OneSignal REST API, targeting the recipient's `external_id` |
| `send-email` | Database Webhook: `notifications` INSERT | Resend email for `organizer_request_*` types only; no-op without `RESEND_API_KEY` |
| `notify-nearby-tournament` | Database Webhook: `tournaments` UPDATE | When `status` becomes `registration_open` and the venue has coordinates, inserts `nearby_tournament` notifications for consenting players in range |

All functions share `_shared/cors.ts`. Two things are **not** Edge Functions: the 48-hour auto-confirm and challenge expiry are `pg_cron` SQL jobs, and admin dispute resolution applies ELO by calling the `apply_elo_changes` RPC directly from the app.

See [ELO_SYSTEM.md](ELO_SYSTEM.md) for the full rating algorithm.

---

## 7. How the Layers Connect

```
Flutter App (Android / iOS / Web)
│
├── Sentry  ←── outermost zone: captures unhandled exceptions + traces (APP_ENV tag)
│
├── Supabase.instance.client  ←── initialised in main.dart with env vars (PKCE)
│   ├── .auth.onAuthStateChange  →  AuthChangeNotifier / authState
│   ├── .from('profiles')        →  currentProfile, profile providers
│   ├── .from('notifications')   →  notificationPanelProvider (realtime stream)
│   ├── .channel('user-sync:<uid>') → realtimeSync (Postgres Changes → invalidate providers)
│   ├── .rpc(...)                →  get_leaderboard_page, get_player_rank, nearby_*, apply_elo_changes (disputes)
│   └── .functions.invoke(...)   →  elo-recalculate, seed-elo, anonymise-account
│
├── go_router (appRouterProvider)
│   └── refreshListenable: AuthChangeNotifier → auto-redirects on sign-in / sign-out
│
└── NotificationService (OneSignal — native only)
    ├── identifyUser(uid)              → links device to Supabase user
    ├── foregroundWillDisplayListener  → shows banner
    └── clickListener                  → resolveRoute() → router.push(path)

Supabase (DEV: eu-central-1 · PROD: eu-west-1)
│
├── PostgreSQL 17
│   ├── Migrations 001–029 (schema, indexes, RLS, triggers, functions, Realtime publication)
│   ├── pg_cron: match-auto-confirm, request-expiry (hourly)
│   └── Database Webhooks (per project, Dashboard config)
│       ├── notifications INSERT → send-notification, send-email
│       └── tournaments UPDATE   → notify-nearby-tournament
│
└── Edge Functions (Deno)
    ├── elo-recalculate          ← app, on confirm
    ├── seed-elo                 ← app, after questionnaire
    ├── anonymise-account        ← app, on account delete
    ├── send-notification        ← webhook → OneSignal
    ├── send-email               ← webhook → Resend
    └── notify-nearby-tournament ← webhook

Cloudflare Pages (ratedtennis.gr) ←── web bundle, uploaded with wrangler
```

---

## 8. First-Run Checklist

Prerequisites: Flutter stable (CI uses 3.38.5), Supabase CLI (2.117 or newer), and Docker Desktop running. On Windows, a shell opened before Docker was installed may not find `docker` — add `C:\Program Files\Docker\Docker\resources\bin` to `PATH`.

```bash
# 1. Install Flutter dependencies + run code generation
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 2. Start the local Supabase stack (replays all migrations + supabase/seed.sql)
supabase start
supabase status       # prints the local API URL and anon key

# 3. Create .env.local from .env.example
#    SUPABASE_URL=http://127.0.0.1:54321 (Android emulator: http://10.0.2.2:54321)
#    SUPABASE_ANON_KEY=<anon key from `supabase status`>, APP_ENV=local
#    leave SENTRY_DSN, ONESIGNAL_APP_ID, GOOGLE_CLIENT_ID blank

# 4. Run against the local stack — log in as alice@rated.test / password123
flutter run -d chrome --dart-define-from-file=.env.local --web-port=3000

# 5. Run against the DEV cloud project (needs .env.dev; Google OAuth works here, not locally)
flutter run -d chrome --dart-define-from-file=.env.dev --web-port=3000
```

`--web-port=3000` matters on web: it matches the Auth redirect URLs. Before changing the database, read [DATABASE.md §7](DATABASE.md#7-applying-migrations). Edge Function deploys go to DEV with `supabase functions deploy <name>` (the linked project) and to PROD only through `./scripts/push-prod.ps1 -Functions <name>`.
