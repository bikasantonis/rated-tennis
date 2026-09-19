# RATED — Backlog

> Updated 2026-09-19. RATED has launched: the web app is live at https://ratedtennis.gr and PROD Supabase is at migration 029, released as `v1.0.0`. This file replaces the pre-launch scaffold task list. What shipped is summarised in §1 (details in `CHANGELOG.md`); everything below it is open.

---

## Legend

| Symbol | Meaning |
|---|---|
| 🔴 **Now** | Correctness, security or GDPR problem affecting production |
| 🟡 **Next** | Release process, environments, testing, compliance hygiene |
| 🟢 **Later** | Features and polish |
| ❓ **Q-xx** | Needs a product decision first (see §5) |

---

## 1. Shipped at Launch

- **Auth** — email/password (≥ 8 chars, one uppercase letter, one digit), GDPR consent checkbox with Privacy Policy / Terms links (timestamp in auth metadata), Google OAuth with a data-disclosure sheet, Apple Sign-In (native), forgot password, change password, session restore with branded splash.
- **Onboarding** — combined intro + login screen; sport-history questionnaire v2 as a one-time dialog → `seed-elo` (age gate 16–90, conditional sub-field validation).
- **Home** — ELO card with sparkline, tier progress, win streak, tier-path hint, five court themes; last 5 settled matches with ELO delta or "Not rated" chip; confetti on a new win.
- **Leaderboard** — `get_leaderboard_page` RPC (50 per page, RATED prestige ordering), club filter, Near Me; row tap opens the player's profile.
- **Profile** — avatar upload/remove, rank, peak ELO, losses, streak, match and tournament history, questionnaire answers.
- **Matches** — submit with six match formats and score validation; inbox confirm/dispute; challenges with a ±1.5 ELO browse, debounced name search, and a max-gain preview; 20 submissions/hour DB limit; 48 h auto-confirm; 72 h challenge expiry; Played/Won counters (028).
- **Tournaments** — Near Me / Upcoming / Registered / Past; registration; organiser dashboard with Drafts; lifecycle controls; ELO-seeded single-elimination bracket with byes; bracket viewer; self-service organiser requests.
- **Admin** — dispute approve/override; organiser request decisions.
- **Notifications** — NF-01 to NF-05, auto-confirm, ELO-excluded, nearby-tournament push, organiser-request push + email; realtime in-app panel with deep links.
- **Location & GDPR** — opt-in location at ~1 km precision with radius, consent enforced by a DB constraint; `anonymise-account` (see §2); hosted legal pages.
- **i18n** — English and Greek throughout.
- **Infrastructure** — separate DEV and PROD projects, CLI linked to DEV, guarded `scripts/push-prod.ps1`, local Docker stack with seed data, Cloudflare Pages hosting, production CORS, Sentry, `com.rated.app` with Android release signing and R8, CI (`pr.yml`, `ci.yml`).

---

## 2. 🔴 Now — Production Correctness & Security

- [ ] 🔴 **Account deletion fails for players with matches** (GDPR Art. 17) — `profiles.id` cascades from `auth.users`, and match/tournament FKs block the cascade ([DATABASE.md §8.1](DATABASE.md#81-account-deletion-fails-for-players-with-match-history)). Reproduce locally with the seed account `alice@rated.test` (has matches), fix with a migration, then run the full sign-up → questionnaire → delete flow and confirm no PII remains.
- [ ] 🔴 **Lock down ELO application** — `apply_elo_changes` is callable by any user and `match_results_update` lets the submitter set `status = 'confirmed'` ([DATABASE.md §8.2](DATABASE.md#82-elo-can-be-applied-without-the-opponents-confirmation)). Restrict status transitions, revoke `EXECUTE` from `anon` / `authenticated`, and move admin approve/override server-side.
- [ ] 🔴 **Verify PROD per-project configuration** — Edge Function secrets, the three Database Webhooks, Auth providers and redirect URLs, Auth rate limits, both cron jobs active ([DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md#prod-configuration-reference)). Remove any `match_results` → `elo-recalculate` webhook if one exists.
- [ ] 🔴 **OneSignal end-to-end on real devices** — Android and iOS, NF-01 to NF-05 plus nearby tournament, including the tap deep links.

---

## 3. 🟡 Next — Release, Environments, Testing, Compliance

### Release
- [ ] 🟡 Record mobile store status (App Store / Play: build numbers, tracks) in DEPLOYMENT_CHECKLIST.md — `pubspec.yaml` is still `1.0.0+1`
- [x] 🟡 Tag the launch commit (`v1.0.0`) and move CHANGELOG `[Unreleased]` into a version section — done 2026-09-19
- [ ] 🟡 Store listings: App Store privacy nutrition label, Play data-safety form
- [ ] 🟡 Confirm the launcher icons are the final brand asset (`assets/images/` holds only `.gitkeep`)

### Environments
- [ ] 🟡 DEV parity: deploy all six Edge Functions, set secrets, create the webhooks, configure the Google provider + redirect URLs (none verified as of 2026-09-13)
- [ ] 🟡 Seed DEV with anonymised test data (the local `supabase/seed.sql` covers only two accounts)
- [ ] 🟡 Decide on staging: remove the `.env.staging` references from `.gitignore` / `.env.example`, or create a real staging project
- [ ] 🟡 Update `README.md` — it still says Frankfurt, `supabase db push` for local setup, Flutter ≥ 3.22, and lists migrations only up to 017

### CI/CD
- [ ] 🟡 Consolidate `pr.yml` and `ci.yml` — both run analyze and tests on the same triggers
- [ ] 🟡 Replay migrations in CI (`supabase db start` + `supabase db reset`) so a broken migration fails the PR
- [ ] 🟡 Web deploy from CI (`flutter build web` + `wrangler pages deploy`) on tag or merge to `main`
- [ ] 🟡 Release workflow for signed AAB / IPA (Fastlane), with signing secrets in GitHub Actions secrets

### Testing
Existing: `test/models/` (EloTier, match validation, Profile JSON) and `test/widget_test.dart`. There is no database test harness.
- [ ] 🟡 SQL tests (pgTAP via `supabase test db`) for `apply_elo_changes` (clamp, friendly void, prestige, idempotency), `sync_match_counters`, and the RLS policies
- [ ] 🟡 Edge Function tests: `elo-recalculate` authorisation, the `seed-elo` rule table
- [ ] 🟡 Integration tests against the local stack with the seed accounts: onboarding, submit + confirm, dispute + admin resolution, challenge flow, tournament registration + bracket, role-gated routes
- [ ] 🟡 Unit tests for `tier_path_calculator.dart` and `streak_utils.dart`
- [ ] 🟡 Accessibility pass at 1.5× font scale (icon-button tooltips are done)

### Security & Compliance
- [ ] 🟡 Session storage: `supabase_flutter` uses its default storage (SharedPreferences / browser localStorage). `flutter_secure_storage` is declared but unused — wire a secure storage adapter on mobile or drop the dependency
- [ ] 🟡 Rotate the Supabase anon key if it appeared in pre-launch logs
- [ ] 🟡 Supabase alerts: Edge Function error rate, DB connection pool
- [ ] 🟡 Privacy policy lists Supabase, Sentry, OneSignal and Nominatim — confirm Resend (organiser-request emails) is covered, along with the SCCs for non-EU processors
- [ ] 🟡 GDPR Art. 7: separate marketing consent — only needed if marketing communications are added

---

## 4. 🟢 Later — Features & Polish

### Notifications
- [ ] 🟢 NF-06 tournament registration confirmed (push + email)
- [ ] 🟢 NF-07 tournament match scheduled
- [ ] 🟢 NF-08 tier promotion / demotion
- [ ] 🟢 NF-09 24 h challenge-expiry warning
- [ ] 🟢 NF-10 weekly ELO digest email
- [ ] 🟢 Per-type notification preferences in Settings
- [ ] 🟢 Route `organizer_request_approved` / `_denied` taps to Settings instead of the admin panel

### Tournaments
- [ ] 🟢 ❓Q-07 Round-robin — accepted by the schema, but bracket generation is single-elimination only
- [ ] 🟢 ❓Q-06 Withdrawal / walkover handling
- [ ] 🟢 Widen `tournament_registrations.elo_at_registration` to `numeric(8,4)` ([DATABASE.md §8.3](DATABASE.md#83-tournament_registrationselo_at_registration-is-an-integer))

### Ratings
- [ ] 🟢 ❓Q-10 ELO decay for inactive players (`elo_history.event_type` already allows `decay`)
- [ ] 🟢 ❓Q-03 K-factor per tier (currently a flat 0.15)

### Profiles & Navigation
- [ ] 🟢 Decide whether public profiles should show a player's full match and ELO history — RLS currently limits both to the viewer's own matches ([DATABASE.md §5](DATABASE.md#5-row-level-security))
- [ ] 🟢 Home: tap a match tile → match detail; tap the ELO card → own profile
- [ ] 🟢 Leaderboard: highlight the current user's row

### Auth
- [ ] 🟢 In-app email-verification gate (today it depends on each project's "Confirm email" setting)
- [ ] 🟢 Biometric unlock — there is no `local_auth` dependency in the current code

### Performance
- [ ] 🟢 Cold-start profiling (first meaningful frame < 2 s on a mid-range Android)
- [ ] 🟢 Leaderboard scroll jank check at 50 rows
- [ ] 🟢 Sentry performance spans around Supabase queries (tracing is on at 0.2)
- [ ] 🟢 Locale-aware date and number formatting audit (EN / EL)

---

## 5. Open Questions

| ID | Question | Status |
|---|---|---|
| Q-01 | Tournament ELO multiplier vs friendlies? | **Resolved** — per-tournament `elo_multiplier` 1.0–1.5, K = 0.15 × multiplier (019) |
| Q-02 | Seed-ELO formula? | **Resolved** — questionnaire v2 ([ELO_SYSTEM.md §3](ELO_SYSTEM.md#3-initial-seed-questionnaire), ADR-13) |
| Q-03 | K-factor per tier? | **Open** — flat K = 0.15 for every tier |
| Q-04 | One club or several per player? | **De facto one** — `profiles.club_id` |
| Q-05 | Challenge ELO filter fixed or adjustable? | **Resolved** — fixed ±1.5 window, plus name search |
| Q-06 | Mid-tournament withdrawal? | **Open** |
| Q-07 | Round-robin scoring (3/1/0 or wins)? | **Open** — round-robin not implemented |
| Q-08 | Figma wireframes? | **Resolved** — references in `docs/figma/` |
| Q-09 | Who can create clubs? | **De facto admins only** (clubs RLS) |
| Q-10 | ELO decay from day one? | **Open** — not implemented |
