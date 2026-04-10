# Changelog

All notable changes to **RATED** are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

> Work in progress toward **Beta (end of Apr 2026)**.

### Added
- **CI/CD — `.github/workflows/pr.yml`** — runs on every PR to `main` and every push to `main`: `flutter pub get` → `build_runner` (drift check) → `flutter gen-l10n` → `flutter analyze` (warnings fatal) → `flutter test test/models/` → `flutter build apk --debug` (compile smoke test). Concurrent runs on the same ref are cancelled. `SUPABASE_URL` and `SUPABASE_ANON_KEY` injected from repo secrets for the build step.
- **Unit tests — 54 tests, all passing** (`flutter test test/models/`):
  - `elo_tier_test.dart` (16): every tier boundary on the [5.0, 10.0] scale — exact boundary, just-below, mid-band.
  - `match_validation_test.dart` (31): `isValidSet` for all 3 set types + `validateMatch` across bo3Standard, bo3SuperTb, oneFullSet, oneMiniSet. Running tests revealed a real bug: submitting 2 sets to a 1-set format returned `InvalidSet` instead of `ExtraSets` — fixed by adding an early `maxSets` guard in `validateMatch`.
  - `profile_test.dart` (7): full deserialisation, `@Default` fallbacks, nullable fields, `deleted_at`, all roles, round-trip.
- **`match_validation.dart` extracted** — pure score-validation logic moved out of `submit_match_screen.dart` to `lib/models/match_validation.dart`; screen now delegates to it.
- **Rate limiting (PRD §6.1)** — migration 009: `trg_match_submission_rate_limit` BEFORE INSERT trigger rejects submissions when a user exceeds 20/hour (raises `P0001 rate_limit_exceeded`); Flutter `submitMatch` maps that error to a user-readable message. Auth rate limits (email: 10/hr, token refresh: 150/hr) added to `config.toml`; mirror in Dashboard → Auth → Rate Limits for production. Migration 009 deployed.
- **`anonymise-account` Edge Function (GDPR Art. 17)** — scrubs PII columns (`display_name` → "Deleted User", `avatar_url`/`club_id` → null, `is_public` → false, `deleted_at` = now) then hard-deletes the Supabase Auth user; profile row retained for FK integrity. Settings "Delete account" now calls this function instead of the old client-side soft-delete.
- **Change password in Settings** — new tile under Account section; dialog validates min-length (8) and confirmation match before calling `auth.updateUser(password:)`; success/error shown via SnackBar. 7 new ARB keys (EN + EL).
- **Leaderboard row tap** — tapping any row navigates to `ProfileScreen` for that player via `/leaderboard/:id` (GoRouter nested route).
- **`SubmitMatchScreen` (SCR-07)** — 4-step wizard (opponent search → outcome → score → date):
  - Step 0: live opponent search (`ilike` on `display_name`, ≥2 chars, excludes self)
  - Step 1: outcome toggle (I won / opponent won)
  - Step 2: per-set score entry (1–5 sets, winner:loser fields), Next locked until all sets valid
  - Step 3: date picker (last 90 days); submits `match_results` row with `status='pending'`
- **`MatchInboxScreen` (SCR-08)** — two tabs:
  - *To Confirm*: pending results submitted by opponent; Confirm (calls `elo-recalculate`) or Dispute (opens score-correction dialog)
  - *Requests*: incoming `match_requests`; Accept or Decline; pull-to-refresh on both tabs
- **`match_provider.dart`** — `searchOpponentsProvider(query)`, `pendingResultsProvider`, `pendingRequestsProvider`, `MatchActions` notifier (`submitMatch`, `confirmMatch`, `disputeMatch`, `acceptRequest`, `declineRequest`)
- **`elo-recalculate` Edge Function** (`supabase/functions/elo-recalculate/index.ts`): validates caller is non-submitting participant, sets `status='confirmed'`, calls `apply_elo_changes` RPC
- **`apply_elo_changes` PL/pgSQL function** (migration 007): ELO formula on 5.0–10.0 scale (K=0.15 friendly / K=0.15×multiplier tournament, D=1.67); no minimum delta; full-precision storage; idempotent via `elo_history` guard
- **`pg_cron` jobs** (migration 007): `match-auto-confirm` (hourly, confirms matches pending >48h + applies ELO), `request-expiry` (hourly, expires stale requests)

### Changed
- **ELO delta on match tiles**:
  - `recentMatchesProvider` and `playerMatchesProvider` now join `elo_history(delta)` — PostgREST RLS ensures only the authenticated user's row is returned
  - Home feed `_MatchTile`: trailing shows `+X.X` / `-X.X` in green/red above the date
  - Profile `_MatchHistoryTile`: same display, but only when `showDelta: true` (own profile); viewing another player's profile shows date only
  - `flutter analyze` 0 errors
- **Score validation + match formats (SCR-07)**:
  - 6 match formats added: `bo3_standard`, `bo3_super_tb` (default), `bo3_mini_3rd`, `bo3_mini_super`, `one_full_set`, `one_mini_set`
  - `MatchFormat` enum added to `match_result.dart` with `@JsonValue` DB mappings and `dbValue` extension
  - Migration 008: `format` column added to `match_results` (CHECK constraint, DEFAULT `bo3_standard`)
  - Per-set type validation: full sets (6-x, 7-5, 7-6), mini-sets (4-x, 5-3, 5-4), super tie-breaks (≥10 win by 2); negatives rejected
  - Match-level validation: clinch detection (no extra sets), completeness check, winner consistency
  - `SubmitMatchScreen` step 1 (format selection) inserted after opponent search; total 5 steps
  - `_SetEntry.isValid` renamed to `isParseable`; `_SetEntry.dispose()` now called in screen `dispose()`
  - `match_provider.submitMatch` updated to accept and persist `format`
  - ARB keys added (EN + EL): 6 format labels, 4 score error messages, score step title
  - `flutter analyze` 0 errors
- **i18n Phase 5 complete** — `login_screen.dart` and `questionnaire_screen.dart` updated with `AppLocalizations`; all 13 screens now use ARB keys instead of hardcoded English strings. `flutter analyze` reports 0 errors.
- **ELO precision widened to `numeric(8,4)`** (migration 007): `profiles.elo_rating`, `questionnaire_responses.seed_elo`, `elo_history` columns, `tournaments.elo_min/elo_max` — full-precision internal storage; display layer rounds to 1dp via `toStringAsFixed(1)`
- `seed-elo` Edge Function: removed pre-storage rounding; stores raw float precision
- `EloScoreCard` widget: displays `eloRating.toStringAsFixed(1)` instead of raw `.toString()`
- **JSON snake_case mapping fixed** on `Profile`, `MatchResult`, `SetScore`, `MatchRequest` models: added `@JsonSerializable(fieldRename: FieldRename.snake)` so Supabase snake_case responses parse correctly
- `TournamentRound.roundOf16` and `TournamentRound.final_` annotated with `@JsonValue` to match DB `round_of_16` / `final` strings

- **`QuestionnaireScreen` (SCR-03)** — 5-step `PageView` wizard with animated progress bar:
  - Step 1: Playing frequency (`rarely` / `monthly` / `weekly` / `multiple_weekly`)
  - Step 2: Self-assessed level (`beginner` / `intermediate` / `advanced` / `competitive`)
  - Step 3: Years playing (mapped to representative integers sent to DB)
  - Step 4: Preferred surface (`clay` / `hard` / `grass` / `indoor` / `no_preference`)
  - Step 5: Tournament experience (`has_competed` boolean)
  - "Next" locked until current step answered; "Back" on all steps > 0; "Get my rating" on final step
  - On submit calls `seed-elo` Edge Function; router gate redirects to `/home` when `questionnaire_done` becomes `true`
- **`QuestionnaireActions` Riverpod notifier** (`questionnaire_provider.dart`) — invokes `supabase.functions.invoke('seed-elo')`, surfaces errors via `AsyncValue`
- **`seed-elo` Edge Function** (`supabase/functions/seed-elo/index.ts`, Deno):
  - Placeholder linear ELO mapping: base 400, +0–500 for level, +0–100 for frequency, +0–75 for years, +25 for tournament experience; clamped to `[400, 1200]`
  - Upserts `questionnaire_responses` row (idempotent retry-safe)
  - Updates `profiles.elo_rating` and sets `questionnaire_done = true`
  - Service-role client; JWT verified via `auth.getUser`; CORS preflight handled
  - *(Q-02 unresolved — formula is placeholder; replace when calibrated)*

### Changed
- **ELO rating scale** changed from integer `[400, 1200]` to `numeric(4,1)` `[5.0, 10.0]` (1 decimal place):
  - `profiles.elo_rating` and `questionnaire_responses.seed_elo` column types updated in `001_initial_schema.sql`
  - New migration `006_elo_scale_change.sql` alters live columns, resets existing rows to `5.0`, updates constraints and tier trigger
  - `EloTier.fromRating()` in `profile.dart` updated to `double` thresholds (6.0/7.0/8.0/9.0/9.5)
  - `Profile.eloRating` field type changed from `int` to `double`; `profile.freezed.dart` regenerated
  - `seed-elo` Edge Function formula rewritten on 5.0–10.0 scale; results rounded to 1 decimal place
  - `004_triggers.sql` `handle_new_user()` default seed changed to `5.0`; `sync_elo_tier()` thresholds updated
- `pubspec.yaml` SDK constraint bumped from `>=3.3.0` to `>=3.8.0` (required by `json_serializable`)

- **`AuthActions` Riverpod notifier** (`auth_provider.dart`) — `signInWithEmail`, `signUpWithEmail`, `signInWithGoogle` (Supabase OAuth browser flow), `signInWithApple` (native `sign_in_with_apple`), `signOut`
- **`LoginScreen` fully wired** (`SCR-02`):
  - Login tab: email + password `TextFormField` with validation, show/hide password toggle, Google and Apple OAuth buttons, loading state disables all inputs, user-friendly error `SnackBar`
  - Register tab: display name (min 2 chars), email, password (`TextFormField` with PRD §5.2 policy: min 8 chars, 1 uppercase, 1 number), GDPR Art. 6 consent checkbox (consent timestamp passed to Supabase user metadata on sign-up), email confirmation `SnackBar`
  - `_friendlyError()` helper maps Supabase error strings to readable messages
- **Platform setup** — `flutter create` run to generate Android/iOS/Web/Desktop platform folders
- **Android deep link** — `io.supabase.rated://login-callback` intent filter added to `AndroidManifest.xml`
- **iOS deep link** — `io.supabase.rated` URL scheme registered in `Info.plist` via `CFBundleURLTypes`
- **`main.dart`** — `detectSessionInUri: true` (default) handles OAuth callback automatically; fixed to use `package:` imports

### Changed
- `google_sign_in` removed from `pubspec.yaml`; Google Sign-In now uses Supabase's built-in `signInWithOAuth` browser flow

- **`LeaderboardScreen` (SCR-05)** — paginated (50/page) leaderboard with optional club filter:
  - Club dropdown in AppBar; active filter shown as dismissible chip
  - Rank medal colours for top 3; `TierBadge` + ELO on each row
  - Pull-to-refresh; prev/next pagination bar
- **`ScheduleMatchScreen` (SCR-09)** — two-step flow (browse → request form):
  - Player list filtered to ±1.5 ELO of current user; limit 50
  - Request form: combined date+time picker (next 30 days), optional venue note + message
  - Submits `match_requests` row with 72-hour expiry
- **`HomeScreen` (SCR-04) — recent matches feed**:
  - Last 5 confirmed matches; won/lost icon with colour; score + date; pull-to-refresh
- **`send-notification` Edge Function** (`supabase/functions/send-notification/index.ts`):
  - Triggered by DB webhook on `notifications` INSERT
  - Delivers push via OneSignal REST API (`include_aliases.external_id`)
  - Attaches `reference_type` / `reference_id` deep-link data payload
- **`recentMatchesProvider`** added to `match_provider.dart`
- **`leaderboard_provider.dart`** — `leaderboardPageProvider(page, clubId)`, `clubsProvider`
- **`schedule_match_provider.dart`** — `browsePlayersProvider(centerElo, eloRange)`, `ScheduleMatchActions.sendRequest`

- **`ProfileScreen` (SCR-06)** — own + other player profiles: header card, ELO sparkline, match history, edit display name, soft-delete
- **`TournamentsListScreen` (SCR-10)** — four status tabs, per-tab Supabase filter, organizer FAB
- **`TournamentDetailScreen` (SCR-11)** — info card, registration CTA, approved participants list
- **`OrganizerDashboardScreen` (SCR-12)** — create tournament form, registration approve/reject
- **`SettingsScreen` (SCR-13)** — language toggle EN/EL, sign out, GDPR soft-delete
- **`DisputeResolutionScreen` (SCR-14)** — admin dispute panel, accept dispute or keep original score
- **`profile_provider.dart`** — `playerProfileProvider`, `eloHistoryProvider`, `playerMatchesProvider`, `ProfileEditActions`
- **`tournament_provider.dart`** — `tournamentsProvider`, `tournamentDetailProvider`, `tournamentRegistrationsProvider`, `TournamentActions`, `disputedMatchesProvider`, `DisputeActions`
- **`EloHistory` + `Tournament` models** — ELO fields corrected to `double`; snake_case JSON mapping added

### Deployed (2026-04-10)
- `supabase functions deploy seed-elo send-notification` — both functions now live
- `supabase db push` — migrations 006 + 007 applied to production/staging
- `send-notification` DB webhook wired in Supabase dashboard (`notifications` INSERT)
- `ONESIGNAL_APP_ID` + `ONESIGNAL_REST_API_KEY` secrets added to Edge Function environment

---

## [0.3.0] — Flutter app scaffold

### Added
- **`main.dart`** — app entry point; initialises Supabase (PKCE auth flow), OneSignal push notifications, and Sentry crash reporting via `--dart-define-from-file`
- **`app.dart`** — `MaterialApp.router` with MD3 theming, system dark/light mode, and EN/EL localisation delegates
- **Router** (`app_router.dart`) — full go_router config covering all 14 screens (PRD §7.3):
  - Auth guard: unauthenticated users redirected to `/login`
  - Questionnaire gate: authenticated users with `questionnaire_done = false` forced to `/questionnaire`
  - `ShellRoute` with `BottomNavShell` for the main 4-tab area
  - Fade transitions for public screens; slide transitions for authenticated screens
- **`AppRoutes`** — typed path constants for all routes
- **`NotificationService`** — OneSignal wrapper; `identifyUser`/`clearUser` tied to Supabase auth state; deep-link tap handler routing `reference_type`→`reference_id` to the correct screen
- **`authStateProvider`** — Riverpod stream provider wrapping `supabase.auth.onAuthStateChange`; syncs OneSignal user identity on sign-in/out
- **`currentProfileProvider`** — fetches the authenticated user's `profiles` row from Supabase
- **14 screen stubs** — all screens from PRD §7.3 created with correct doc comments and TODOs:
  - `SCR-01` OnboardingScreen — 3-slide PageView with animated dot indicators, navigates to Login on "Get Started"
  - `SCR-02` LoginScreen — tabbed Login / Register layout with email, password, Google, Apple placeholders
  - `SCR-03` QuestionnaireScreen — stub
  - `SCR-04` HomeScreen — live `EloScoreCard` + FABs for Submit/Schedule; recent matches placeholder
  - `SCR-05` to `SCR-14` — stubs with Scaffold + AppBar + centred TODO text
- **`BottomNavShell`** — `NavigationBar` with 4 destinations (Home, Leaderboard, Matches, Tournaments); active tab derived from `GoRouterState.matchedLocation`
- **`EloScoreCard`** widget — displays ELO rating (Barlow Condensed 72pt), `TierBadge`, and Played / Won / Win% stats
- **`TierBadge`** widget — pill badge in tier colour with accessible `Semantics` label; supports `small` variant

---

## [0.2.0] — Theme & design tokens

### Added
- **`AppColors`** — all design tokens from PRD §7.2, WCAG 2.1 AA verified:
  - Light theme palette (primary blue `#1B4F8A`, secondary green, clay tertiary)
  - Dark mode tertiary override (`#E8845C`)
  - Tier badge colours: Beginner (grey), Bronze, Silver, Gold, Platinum, Elite
  - Semantic colours: `eloGain`, `eloLoss`, `matchConfirmed`, `matchDisputed`
- **`AppTheme`** — MD3 `ThemeData` for light and dark modes:
  - Typography: Barlow Condensed (display/headline) + Inter (body/label) via Google Fonts
  - Global `CardTheme` (elevation 1, 12 px radius), `InputDecorationTheme` (filled, 12 px radius), `FilledButtonTheme` (pill shape, 48 px min height, full width)
- **`EloTier` enum** (in `profile.dart`) — 6 tiers with `fromRating()` factory and `label` getter

---

## [0.1.0] — Supabase database

### Added
- **Migration 001 — Initial schema** — all tables from PRD §8:
  - `clubs` — tennis club registry
  - `profiles` — extends `auth.users` 1-to-1; ELO rating (default 800), tier, role, soft-delete
  - `questionnaire_responses` — one-time skill assessment per player
  - `elo_history` — append-only ELO ledger (match, tournament_match, decay, admin_adjustment)
  - `match_results` — friendly & tournament results with score JSONB, dispute workflow, auto-confirm flag
  - `match_requests` — 72-hour expiring match invitations
  - `tournaments` — single-elimination and round-robin formats; ELO bracket (min/max), multiplier (1.0–2.0)
  - `tournament_registrations` — admission workflow with seed assignment
  - `notifications` — in-app notification inbox with `reference_type`/`reference_id` deep-link payload
- **Migration 002 — Indexes** — all mandatory indexes from PRD §8.3:
  - `profiles`: ELO leaderboard sort + club filter, tier, `updated_at`
  - `match_results`: winner/loser history, tournament bracket, pending auto-confirm filter
  - `elo_history`: player sparkline (player + `created_at DESC`)
  - `tournament_registrations`: by tournament+status, by player
  - `match_requests`: recipient inbox, expiry cron filter
  - `notifications`: recipient + unread + recency
- **Migration 003 — RLS policies** — permission matrix from PRD §5.5:
  - Helper functions: `current_user_role()`, `is_admin()`, `is_organizer_or_admin()`
  - Row-level security enabled on all 9 application tables
  - Per-table select/insert/update/delete policies for player, organizer, and admin roles
- **Migration 004 — Triggers**:
  - `set_updated_at()` — auto-updates `updated_at` on profiles, match_results, match_requests, tournaments
  - `handle_new_user()` — auto-creates a `profiles` row on `auth.users` INSERT (security definer)
  - `sync_elo_tier()` — derives `elo_tier` from `elo_rating` on insert/update (beginner < 800 < bronze < 1000 < silver < 1200 < gold < 1400 < platinum < 1600 < elite)
- **Migration 005 — Edge Function stubs** — documented webhook/cron bindings for all 5 Edge Functions:
  - `elo-recalculate` — DB webhook on `match_results` status → confirmed/overridden
  - `match-auto-confirm` — hourly cron, auto-confirms matches pending > 48 h
  - `request-expiry` — hourly cron, expires pending match requests past `expires_at`
  - `seed-elo` — HTTP POST after questionnaire submission
  - `send-notification` — DB webhook on `notifications` INSERT → OneSignal REST API
  - `elo-decay` — daily cron (disabled by default, pending Q-10)

### Added — Dart data models (Freezed + JSON serializable)
- `Profile` — with `EloTier` and `UserRole` enums
- `MatchResult` — with `MatchType`, `MatchStatus`, `TournamentRound` enums and score JSONB
- `MatchRequest` — with `MatchRequestStatus` enum
- `Tournament` — with `TournamentFormat`, `TournamentStatus` enums
- `EloHistory` — with `EloEventType` enum
- `NotificationItem`

### Added — Dependencies (`pubspec.yaml`)
- `supabase_flutter ^2.5.6`, `google_sign_in ^7.2.0`, `sign_in_with_apple ^7.0.1`
- `onesignal_flutter ^5.2.5`
- `flutter_riverpod ^3.1.0`, `riverpod_annotation ^4.0.0`
- `go_router ^17.1.0`
- `flutter_secure_storage ^10.0.0`
- `google_fonts ^8.0.2`, `fl_chart ^1.2.0`, `cached_network_image ^3.4.1`
- `freezed_annotation ^3.1.0`, `json_annotation ^4.9.0`
- `sentry_flutter ^9.16.0`, `intl ^0.20.2`
