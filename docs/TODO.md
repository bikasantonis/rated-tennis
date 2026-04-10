# RATED — Implementation TODO List

> Tracks every outstanding task from the scaffold. Organised by layer and priority (Must / Should / Could) matching PRD MoSCoW.
> PRD open questions (Q-01 through Q-10) are marked separately — they require a **decision before code can be written**.

---

## Legend

| Symbol | Meaning |
|---|---|
| 🔴 **Must** | Launch blocker — required for MVP (end Jun 2026) |
| 🟡 **Should** | High value — required before public launch (Aug 2026) |
| 🟢 **Could** | Nice-to-have — can slip to v2 |
| ❓ **Q-xx** | Open question — decision required before this can be implemented |
| 📅 **Beta** | Required for TestFlight / Internal Play (end Apr 2026) |

---

## 0. Before Any Code — Open Questions

These are blocking decisions from PRD §12.1. Each blocks one or more downstream tasks.

| ID | Question | Blocks | Due |
|---|---|---|---|
| ❓ Q-01 | Should tournament match wins apply ELO multiplier > 1.0 vs friendly matches? | `elo-recalculate` Edge Function, `elo_multiplier` default | Before MVP |
| ❓ Q-02 | What is the exact seed-ELO formula? Which weights apply to each questionnaire field? | `seed-elo` Edge Function, `QuestionnaireScreen` | Before Beta |
| ❓ Q-03 | What is the ELO K-factor per tier? (Default K=32 globally until confirmed) | `elo-recalculate` Edge Function | After Beta |
| ❓ Q-04 | Can a player belong to multiple clubs, or strictly one club per player in v1? | `profiles.club_id` cardinality, potential `player_clubs` join table | Before Beta |
| ❓ Q-05 | Should the ±150 ELO filter on Schedule Match be fixed or user-adjustable? | `ScheduleMatchScreen` UI, possibly `profiles` table new column | Before Beta |
| ❓ Q-06 | What happens to a player's ELO and bracket position if they withdraw from a tournament mid-event? | Tournament state machine, walkover logic | Before MVP |
| ❓ Q-07 | Should round-robin use a points table (3/1/0) or straight win count? | Bracket progression logic | Before MVP |
| ❓ Q-08 | Will a Figma wireframe be provided, or does Claude Code generate best-effort layouts from PRD §7? | All screen implementations | Before Foundation (now) |
| ❓ Q-09 | Can any organizer create a club, or must clubs be pre-seeded by admin? | `CreateClubScreen` (new screen?), RLS policy | Before Beta |
| ❓ Q-10 | Should ELO decay (FR-13) be enabled from day one or disabled until user base is large enough? | `elo-decay` Edge Function enable/disable flag | Before Beta |

---

## 1. OneSignal Push Notification Setup

- [ ] 🔴 Create OneSignal account and app at dashboard.onesignal.com; choose "Flutter" SDK
- [ ] 🔴 Add `ONESIGNAL_APP_ID` to `.env.dev` / `.env.staging` / `.env.production`
- [ ] 🔴 **Android**: upload FCM server key in OneSignal dashboard (Settings → Push → Google Android); download and add `google-services.json` to `android/app/` _(OneSignal still needs FCM credentials server-side, but the Flutter app no longer imports `firebase_core`)_
- [ ] 🔴 **iOS**: upload APNs Auth Key (p8) in OneSignal dashboard (Settings → Push → Apple iOS); OneSignal handles provisioning — no manual certificate rotation
- [ ] 🔴 Set OneSignal External User ID to Supabase `uid` after login so notifications are user-targeted: `OneSignal.login(supabaseUserId)`
- [ ] 🔴 Call `OneSignal.logout()` on sign-out so the device is no longer associated with the user
- [ ] 🔴 Handle **foreground notifications**: listen to `OneSignal.Notifications.addForegroundWillDisplayListener` and show in-app banner
- [ ] 🔴 Handle **notification tap** (background / terminated): listen to `OneSignal.Notifications.addClickListener`, parse `reference_type` + `reference_id` from notification data, deep-link via go_router
- [ ] 🟡 Write Supabase Edge Function `send-notification` that calls OneSignal REST API (`POST /notifications`) — triggered by DB webhook on `notifications` INSERT
- [ ] 🟡 Pass `headings`, `contents`, `data.reference_type`, `data.reference_id` in OneSignal payload so tap handler can route correctly

---

## 2. Authentication (SCR-02 — `login_screen.dart`)

- [ ] 🔴 Wire **email + password** sign-in to `Supabase.instance.client.auth.signInWithPassword()`
- [ ] 🔴 Wire **email + password** registration to `auth.signUp()` with `display_name` in metadata
- [ ] 🔴 Wire **Google Sign-In** button using `google_sign_in` package + Supabase OAuth flow
- [ ] 🔴 Wire **Apple Sign-In** button using `sign_in_with_apple` + Supabase OAuth (required for App Store)
- [ ] 🔴 Add **GDPR consent checkbox** with timestamp stored in `profiles` (Art. 6 compliance)
- [ ] 🔴 Inline **privacy policy link** at registration (Art. 13 compliance)
- [ ] 🔴 Add **password validation** (min 8 chars, 1 uppercase, 1 number — PRD §5.2)
- [ ] 🔴 Handle auth errors gracefully (wrong password, email taken, network error)
- [ ] 🔴 Implement **biometric prompt** if session token exists (`local_auth` package)
- [ ] 🟡 Add **forgot password** flow via Supabase `resetPasswordForEmail()`
- [ ] 🟡 Add **email verification** gate before accessing the app

---

## 3. Onboarding Questionnaire (SCR-03 — `questionnaire_screen.dart`)

- [ ] 🔴 Build 5–7 question step-by-step UI (PageView or Stepper)
  - Q1: Playing frequency (`rarely / monthly / weekly / multiple_weekly`)
  - Q2: Self-assessed level (`beginner / intermediate / advanced / competitive`)
  - Q3: Years playing (number input, 0–50)
  - Q4: Preferred surface (`clay / hard / grass / indoor / no_preference`) — optional
  - Q5: Has competed in official tournaments? (yes/no)
- [ ] 🔴 ❓ Q-02 Call `seed-elo` Edge Function with questionnaire answers on submit
- [ ] 🔴 Insert row into `questionnaire_responses` table
- [ ] 🔴 Update `profiles.questionnaire_done = true` after successful seed ELO assignment
- [ ] 🔴 Router redirect logic already handles the guard — ensure `currentProfileProvider` invalidates after update

---

## 4. Home / Dashboard (SCR-04 — `home_screen.dart`)

- [ ] 🔴 Implement **recent match list** (last 5 matches from `match_results` where `winner_id = uid OR loser_id = uid`)
- [ ] 🔴 Show ELO delta (±points) on each recent match row
- [ ] 🟡 Tap on recent match row → navigate to match detail / dispute screen
- [ ] 🟡 Wire **ELO score card** tap → navigate to own player profile (SCR-06)
- [ ] 🟡 Show **pending actions badge** count (pending match results + unread requests)

---

## 5. Leaderboard (SCR-05 — `leaderboard_screen.dart`)

- [ ] 🔴 Implement paginated Supabase query: `.from('profiles').select(...).order('elo_rating', ascending: false).range(0, 49)`
- [ ] 🔴 Build **leaderboard row** widget: rank number (Barlow Condensed), avatar, name + club, `TierBadge`, ELO score right-aligned
- [ ] 🔴 Implement **infinite scroll** / load-more (batches of 50 per PRD §5.1.2 FR-09)
- [ ] 🔴 Implement **Global / Club filter** tab or chip (club filter adds `.eq('club_id', clubId)`)
- [ ] 🔴 Tap leaderboard row → navigate to `ProfileScreen(playerId: id)`
- [ ] 🟡 Highlight current user's row

---

## 6. Player Profile (SCR-06 — `profile_screen.dart`)

- [ ] 🔴 Load profile data: own (`currentProfileProvider`) or other (`playerId` param query)
- [ ] 🔴 Display avatar (`cached_network_image`), display name, club, tier badge, ELO
- [ ] 🟡 **ELO sparkline chart** using `fl_chart` LineChart — query `elo_history` ordered by `created_at DESC LIMIT 20`
- [ ] 🟡 Match history list (W/L, score, opponent, date, ELO delta)
- [ ] 🟡 W/L stats bar (wins / losses / win %)
- [ ] 🔴 **Edit button** (own profile only) → edit display name, club, avatar upload to Supabase Storage
- [ ] 🟡 Avatar upload: pick image, resize to max 1024px, upload JPEG to `avatars/{uid}.jpg` bucket

---

## 7. Submit Match Result (SCR-07 — `submit_match_screen.dart`)

- [ ] 🔴 **Opponent search** — search bar querying `profiles.display_name ILIKE '%query%'` with ±ELO awareness
- [ ] 🔴 **Score entry form** — pair of number pickers per set (`6 | 3`), Add Set button (max 5 sets), Remove Set button
- [ ] 🔴 **Score validation** (PRD FR-22): valid sets are 6-x (win by 2), 7-5, 7-6 (tiebreak); reject 5-0, 6-6, 7-3 etc.
- [ ] 🔴 **Date picker** for `played_at`
- [ ] 🔴 Submit inserts row into `match_results` with `status = 'pending'`
- [ ] 🔴 Trigger **NF-01 notification** (opponent notified of pending result — via Edge Function or Supabase webhook)
- [ ] 🟡 Inline validation error messages per field

---

## 8. Match Inbox (SCR-08 — `match_inbox_screen.dart`)

- [ ] 🔴 Query **pending match results** where `loser_id = uid AND status = 'pending'` (need to confirm or dispute)
- [ ] 🔴 Query **incoming match requests** where `recipient_id = uid AND status = 'pending'`
- [ ] 🔴 **Confirm match** — update `status = 'confirmed'`, triggers `elo-recalculate` via DB webhook
- [ ] 🔴 **Dispute match** — update `status = 'disputed'`, store `dispute_score` JSONB, set `disputed_by`
- [ ] 🔴 **Accept match request** — update `match_requests.status = 'accepted'`, send NF-05 notification
- [ ] 🔴 **Decline match request** — update `status = 'declined'`, send NF-05 notification
- [ ] 🔴 Sort all items by recency (most recent first)
- [ ] 🟡 Badge count on bottom nav tab (unread count from `notifications` + pending items)

---

## 9. Schedule Match (SCR-09 — `schedule_match_screen.dart`)

- [ ] 🔴 Browse players within ❓Q-05 ±150 ELO: `.from('profiles').select(...).gte('elo_rating', myElo - 150).lte('elo_rating', myElo + 150)`
- [ ] 🔴 Filter by club chip
- [ ] 🔴 Tap player → open **match request form**: proposed date/time (DateTimePicker), venue note (text field), optional message
- [ ] 🔴 Submit inserts row into `match_requests` (`expires_at` auto-set by DB generated column)
- [ ] 🔴 Send **NF-04 push notification** to recipient
- [ ] 🟡 ❓Q-05 User-adjustable ELO range slider if decided
- [ ] 🟢 ❓Q-29 Google Maps venue suggestions on request form

---

## 10. Tournaments

### Tournaments List (SCR-10 — `tournaments_list_screen.dart`)
- [ ] 🔴 Query `tournaments` with filter tabs: Open (status = `registration_open`), Registered (player in `tournament_registrations`), Past (status = `completed`)
- [ ] 🔴 Show tournament card: name, date range, ELO bracket, format, registration status chip
- [ ] 🔴 Tap card → navigate to `TournamentDetailScreen`

### Tournament Detail (SCR-11 — `tournament_detail_screen.dart`)
- [ ] 🔴 Show tournament info header (name, date, ELO range, format, organiser)
- [ ] 🔴 **Register CTA** button — inserts `tournament_registrations` row with `elo_at_registration` snapshot; disabled if ELO outside `elo_min`–`elo_max` or already registered
- [ ] 🔴 **Bracket viewer** — single-elimination: left-to-right tree widget; round-robin: scrollable grid table
- [ ] 🔴 Registered players list
- [ ] 🟡 Send **NF-06 notification** on registration confirmation
- [ ] 🟢 ❓Q-40 Seeding by ELO on draw generation

---

## 11. Organizer Dashboard (SCR-12 — `organizer_dashboard_screen.dart`)

- [ ] 🔴 **Create tournament** form: name, date range, ELO min/max, format, max players, description
- [ ] 🔴 **Manage registrations**: list of pending registrations; Admit / Reject buttons
- [ ] 🔴 **Organizer admission override**: admit player outside ELO bracket (FR-33)
- [ ] 🔴 **Generate bracket**: call bracket generation logic; single-elimination requires `max_players` to be power of 2
- [ ] 🔴 **Submit tournament match result**: select match slot from bracket, enter score, advance bracket
- [ ] 🟡 Tournament status lifecycle management (draft → registration_open → in_progress → completed)
- [ ] 🔴 Role guard: redirect non-organizer/admin users away from this screen

---

## 12. Settings (SCR-13 — `settings_screen.dart`)

- [ ] 🟡 **Language toggle** EN / EL — updates `profiles.preferred_language` and calls `setState` on app locale
- [ ] 🟡 **Notification preferences** — per-type toggles (match submitted, match confirmed, etc.)
- [ ] 🔴 **Change password** — Supabase `auth.updateUser(password: newPassword)`
- [ ] 🔴 **Delete account** flow — confirmation dialog → call anonymisation Edge Function → sign out (GDPR Art. 17)
- [ ] 🔴 **Privacy policy link** inline in settings

---

## 13. Admin — Dispute Resolution (SCR-14 — `dispute_resolution_screen.dart`)

- [ ] 🔴 Query all matches where `status = 'disputed'` (admin only — RLS enforced)
- [ ] 🔴 Show both score versions side by side: `score` (submitter's) vs `dispute_score` (opponent's)
- [ ] 🔴 **Approve disputed score** — accept submitter's version, update `status = 'confirmed'`, set `resolved_by`
- [ ] 🔴 **Override with correct score** — update `score` field, update `status = 'overridden'`, set `resolved_by`
- [ ] 🔴 Both actions trigger `elo-recalculate` via DB webhook

---

## 14. Supabase Edge Functions (to be created in `supabase/functions/`)

- [ ] 🔴 `elo-recalculate/index.ts` — ELO delta computation (K=32 default ❓Q-03); idempotency guard; serializable transaction; writes 2 `elo_history` rows; updates `profiles.elo_rating`; triggers `sync_elo_tier` via DB trigger
- [ ] 🔴 `match-auto-confirm/index.ts` — cron: sets `status = 'confirmed'`, `auto_confirmed = true` for 48h-old pending matches; sends NF-02 in-app notification to both players
- [ ] 🔴 `request-expiry/index.ts` — cron: expires pending match requests past `expires_at`
- [ ] 🔴 ❓Q-02 `seed-elo/index.ts` — computes initial ELO from questionnaire; writes `questionnaire_responses.seed_elo`; updates `profiles.elo_rating`
- [ ] 🟢 ❓Q-10 `elo-decay/index.ts` — daily decay for inactive players (disabled until user base grows)

---

## 15. Notifications

- [ ] 🔴 **NF-01** Push + in-app when match result submitted against user
- [ ] 🔴 **NF-02** In-app when match auto-confirmed (48h timeout)
- [ ] 🔴 **NF-03** Push + in-app when match result disputed
- [ ] 🔴 **NF-04** Push + in-app when match request received
- [ ] 🔴 **NF-05** Push + in-app when match request accepted/declined
- [ ] 🔴 **NF-06** Push + email when tournament registration confirmed
- [ ] 🔴 **NF-07** Push + in-app when tournament match scheduled
- [ ] 🟡 **NF-08** Push + in-app on ELO tier promotion or demotion
- [ ] 🟢 **NF-09** Push warning 24h before match request expiry
- [ ] 🟢 **NF-10** Weekly ELO digest email

---

## 16. i18n / Localisation

- [ ] 🔴 Create `lib/l10n/app_en.arb` with all English strings
- [ ] 🔴 Create `lib/l10n/app_el.arb` with all Greek strings
- [ ] 🔴 Replace all hardcoded English strings in screens with `AppLocalizations.of(context)!.xxx`
- [ ] 🟡 Format dates with `intl` `DateFormat` per locale (DD/MM/YYYY for `el`, MM/DD/YYYY for `en`)
- [ ] 🟡 Format ELO numbers with `NumberFormat` (no decimal places, locale-aware thousand separator)

---

## 17. CI / CD Pipeline

- [ ] 🔴 Create `.github/workflows/pr.yml` — flutter analyze, flutter test, accessibility scanner, Deno Edge Function tests, integration tests against Supabase staging
- [ ] 🔴 Create `.github/workflows/merge_main.yml` — all PR steps + `flutter build apk --release` + `flutter build ios --no-codesign` + `supabase functions deploy` to staging + `supabase db push` to staging
- [ ] 🔴 Create `.github/workflows/release.yml` — triggered by Git tag `vX.Y.Z`; applies migrations to production; deploys functions to production; Fastlane IPA → App Store Connect; Fastlane AAB → Google Play internal track
- [ ] 🔴 Store signing secrets in GitHub Actions encrypted secrets (never in repo)
- [ ] 🔴 Set up Supabase staging project and seed it with anonymised test data

---

## 18. Testing

- [ ] 🔴 Unit tests for `EloTier.fromRating()` boundary values (799 → beginner, 800 → bronze, etc.)
- [ ] 🔴 Unit tests for score validation logic (valid: 6-3, 7-5, 7-6; invalid: 7-3, 6-6, 5-0, >5 sets)
- [ ] 🔴 Unit tests for ELO delta calculation (win vs higher-ranked, loss vs lower-ranked, K-factor scaling)
- [ ] 🔴 Unit tests for `Profile.fromJson` / `toJson` round-trip (all fields including nullables)
- [ ] 🔴 Widget test: `TierBadge` renders correct colour for all 6 tiers; no overflow at 1.5× font scale
- [ ] 🔴 Widget test: `EloScoreCard` displays correct ELO value and tier badge
- [ ] 🔴 Widget test: match score entry form — Add Set disabled after 5 sets, invalid score shows error
- [ ] 🔴 Widget test: auth redirect (unauthenticated → login, authenticated + questionnaire false → questionnaire)
- [ ] 🔴 Integration test IT-01: new player onboarding (register → questionnaire → ELO assigned → dashboard)
- [ ] 🔴 Integration test IT-02: submit + confirm match → both ELOs updated, `elo_history` rows created
- [ ] 🔴 Integration test IT-03: submit + dispute → admin override → correct ELO applied
- [ ] 🔴 Integration test IT-04: 48-hour auto-confirm cron simulation
- [ ] 🔴 Integration test IT-05: match request flow (send → accept → submit result)
- [ ] 🔴 Integration test IT-06: tournament registration + draw generation
- [ ] 🔴 Integration test IT-07: tournament match submission with ELO multiplier
- [ ] 🔴 Integration test IT-08: role-gated access (player blocked from organizer route)
- [ ] 🔴 Edge Function tests: `elo-recalculate` idempotency, tournament multiplier, DB error rollback
- [ ] 🔴 Accessibility: zero `flutter_accessibility_scanner` violations on merge to main

---

## 19. Security & Compliance

- [ ] 🔴 Rate limiting: implement in Edge Functions — max 20 match submissions / user / hour; max 10 auth attempts / 15 min (PRD §6.1)
- [ ] 🔴 GDPR Art. 7: separate consent checkboxes for marketing vs. functional data in Settings
- [ ] 🔴 GDPR Art. 17: `anonymise-account` Edge Function — anonymises PII within 30 days of deletion request
- [ ] 🔴 GDPR Art. 25: confirm no third-party analytics in v1
- [ ] 🟡 GDPR Art. 44: FCM Standard Contractual Clauses acknowledgement in privacy policy
- [ ] 🔴 Store JWT refresh tokens in `flutter_secure_storage` (iOS Keychain / Android Keystore) — **never** in SharedPreferences (PRD §6.1)
- [ ] 🔴 All RATING calculations must run server-side only (Edge Functions) — client sends raw scores, never computed deltas
- [ ] 🔴 Privacy Nutrition Label (App Store) — complete before submission

---

## 20. Performance & Polish

- [ ] 🟡 Riverpod stale-while-revalidate pattern on all remote data providers (return cache → refresh in background)
- [ ] 🟡 15-minute cache TTL on profile + leaderboard data via `flutter_cache_manager`
- [ ] 🟡 Use `.range()` pagination on all list queries — never unbounded `SELECT *`
- [ ] 🟡 App cold-start profiling: first meaningful frame < 2 s on Snapdragon 665 (PRD §6.1)
- [ ] 🟡 No janky frames (>16 ms) during leaderboard scroll of 50 rows
- [ ] 🔴 App logo — replace 'TR' placeholder monogram with final brand asset before App Store submission
- [ ] 🟢 Sentry performance tracing on Supabase query spans
