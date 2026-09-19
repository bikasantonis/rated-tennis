# RATED — Deployment Checklist

> Updated 2026-09-14. RATED is live. This file is the checklist for every release from now on, plus a record of what the launch did and did not cover. Environments, hosting and the CLI setup are in [ARCHITECTURE.md §2](ARCHITECTURE.md#2-environments--hosting); the migration workflow is in [DATABASE.md §7](DATABASE.md#7-applying-migrations).

---

## Every Release

### 1. Code

- [ ] CI green on `main` (`pr.yml`: `flutter analyze --fatal-warnings`, model tests, debug APK; `ci.yml`: analyze, web build, `flutter test`)
- [ ] Changed flows exercised against the local stack (`supabase db reset`, seed accounts), then against DEV

### 2. Database — only if `supabase/migrations/` changed

- [ ] Each new migration replays cleanly from empty: `supabase db reset`
- [ ] Pushed to DEV and verified there: `supabase migration list` → `supabase db push --dry-run` → `supabase db push`
- [ ] Backward compatible with the app version users currently have installed (the database ships before the app)
- [ ] Committed and merged to `main`, working tree clean
- [ ] `./scripts/push-prod.ps1 -DryRunOnly` lists only the expected migrations
- [ ] `./scripts/push-prod.ps1` applied, and its output confirms the CLI is linked to DEV again

### 3. Edge Functions — only if `supabase/functions/` changed

- [ ] Deployed to DEV (`supabase functions deploy <name>`) and tested
- [ ] Deployed to PROD with `./scripts/push-prod.ps1 -Functions <name>[,<name>]` (it applies any pending migrations first)
- [ ] Any new web origin added to `ALLOWED_ORIGINS` in `supabase/functions/_shared/cors.ts`
- [ ] Any new secret set on **both** projects (Dashboard → Project Settings → Edge Functions)

### 4. Web — ratedtennis.gr

- [ ] `flutter build web --dart-define-from-file=.env.production`
- [ ] `wrangler pages deploy build/web --branch=main`
- [ ] Smoke test https://ratedtennis.gr: sign in (email and Google), Home loads, confirm a match; `https://ratedtennis.com` still 301-redirects to `.gr`

### 5. Mobile

- [ ] Bump `version:` in `pubspec.yaml` — the build number must increase for every store upload
- [ ] Android: `flutter build appbundle --release --dart-define-from-file=.env.production` (signed via `android/app/key.properties`; R8 enabled)
- [ ] iOS: `flutter build ipa --dart-define-from-file=.env.production`
- [ ] TestFlight / Play internal-track sign-off before promoting

### 6. After Release

- [ ] Move `[Unreleased]` in `CHANGELOG.md` under a version heading and tag the commit `vX.Y.Z`
- [ ] Watch Sentry (`environment:production`) and the Supabase Edge Function logs for new errors
- [ ] Supabase → Usage → Realtime: peak connections and messages. The Free plan allows 200 concurrent connections and 2 M messages/month (one socket per open app; each change reaches at most the two players). Move PROD to Pro if peak connections regularly exceed ~140

---

## PROD Configuration Reference

`db push` does not carry any of this. It must be set on the PROD project by hand and mirrored on DEV.

| Area | Required |
|---|---|
| Edge Function secrets | `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY`, `RESEND_API_KEY`, `FROM_EMAIL` |
| Database Webhooks | `notifications` INSERT → `send-notification`; `notifications` INSERT → `send-email`; `tournaments` UPDATE → `notify-nearby-tournament` |
| Auth providers | Email; Google (OAuth client ID + secret); Apple |
| Auth URLs | Site URL `https://ratedtennis.gr`; redirect URLs for the web origin and the native callback `io.supabase.rated://login-callback` |
| Auth rate limits | Match `[auth.rate_limit]` in `supabase/config.toml` (10 emails/hour, 150 token refreshes) |
| pg_cron | `match-auto-confirm` and `request-expiry` — created by migrations; check they are active |

`elo-recalculate` needs no webhook — the app calls it directly. If a `match_results` → `elo-recalculate` webhook exists on either project, it can only fail (no user JWT, no `match_id`) and should be removed.

### Read-only verification queries (SQL editor)

```sql
SELECT jobname, schedule, active FROM cron.job;                                       -- both jobs, active
SELECT indexname FROM pg_indexes WHERE tablename IN ('elo_history', 'notifications');  -- idx_elo_history_match_id, idx_notifications_dedup
SELECT conname FROM pg_constraint WHERE conrelid = 'public.profiles'::regclass;       -- chk_location_consent_required
SELECT tgname FROM pg_trigger
 WHERE tgrelid = 'public.match_results'::regclass AND NOT tgisinternal;               -- includes trg_match_counters
SELECT tablename FROM pg_publication_tables
 WHERE pubname = 'supabase_realtime';                -- match_requests, match_results, notifications, profiles (029)
```

Read-only only — schema changes never go through the SQL editor.

---

## Launch Record (as of 2026-09-14)

### Done

- [x] Web app live on Cloudflare Pages at https://ratedtennis.gr (responding at the time of writing); `ratedtennis.com` → 301 → `.gr`
- [x] PROD Supabase (`jkjndgcjyalmglnvvdrd`, eu-west-1) at migrations 001–028, including the `elo_history.match_id` index (023), notification dedup + cron guard (024), and the location-consent constraint (025)
- [x] DEV brought level with PROD and made the CLI's default link; guarded `scripts/push-prod.ps1`
- [x] Full migration chain verified from empty on the local Postgres 17 stack
- [x] Production CORS origins (`ratedtennis.gr`, `ratedtennis.com`), verified against the deployed functions
- [x] Sentry DSN in `.env.dev` and `.env.production`; events tagged by `APP_ENV`
- [x] `.env.production` created (gitignored)
- [x] Application ID `com.rated.app`; Android release signing and R8
- [x] Privacy Policy and Terms URLs resolve (GitHub Pages)
- [x] `anonymise-account` deletes `questionnaire_responses`
- [x] CI workflows (`pr.yml`, `ci.yml`)
- [x] Seed-ELO formula finalised (questionnaire v2, ADR-13)

### Open or Unverified

- [ ] **Account deletion end-to-end** — expected to fail for any player with matches ([DATABASE.md §8.1](DATABASE.md#81-account-deletion-fails-for-players-with-match-history)); GDPR Art. 17
- [ ] **ELO integrity** — a submitter can confirm their own match or apply ELO directly ([DATABASE.md §8.2](DATABASE.md#82-elo-can-be-applied-without-the-opponents-confirmation))
- [ ] Mobile store releases (App Store / Play) — not recorded in the repo: `pubspec.yaml` is still `1.0.0+1` and there are no git tags
- [ ] Every row of the PROD configuration reference above verified (secrets, webhooks, Auth providers/URLs, rate limits, cron)
- [ ] OneSignal push end-to-end on real Android and iOS devices (NF-01 – NF-05, nearby tournament)
- [ ] The same per-project configuration on DEV (unverified as of 2026-09-13)
- [ ] Supabase alerts: Edge Function error rate > 1 %, DB connections > 80 % of the pool
- [ ] Anon key rotation, if the key appeared in any pre-launch logs
- [ ] RLS review ([DATABASE.md §5](DATABASE.md#5-row-level-security) and §8)
- [ ] Store listings: App Store privacy nutrition label, Play data-safety form, final launcher icon

---

## Open Product Questions

Q-03 (K-factor per tier), Q-06 (withdrawal / walkover), Q-07 (round-robin scoring), Q-10 (ELO decay) — see [TODO.md §5](TODO.md#5-open-questions).
