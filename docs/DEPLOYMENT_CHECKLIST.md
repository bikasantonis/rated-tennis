# RATED — Deployment Checklist

Use this list before every production deployment. Items marked **LAUNCH** are one-time actions required before the first public release.

---

## Before Every Deployment

- [ ] `flutter analyze` — zero issues
- [ ] All unit tests pass (`flutter test`)
- [ ] `supabase db push` — confirm all pending migrations applied cleanly
- [ ] Review Supabase Edge Function logs for errors from the previous release
- [ ] Verify OneSignal push notifications working end-to-end on a real device (NF-01 through NF-07)

---

## LAUNCH — One-time Pre-Production Actions

### Security

- [ ] **Update CORS allowed origins** — edit `supabase/functions/_shared/cors.ts` and add the production web domain to `ALLOWED_ORIGINS`:
  ```typescript
  "https://app.ratedtennis.gr",  // replace with actual domain
  ```
  Then redeploy all Edge Functions: `supabase functions deploy`

- [ ] Rotate Supabase anon key and update `.env.production` (keys exposed in any staging logs)
- [ ] Enable Supabase Auth rate limiting in the Dashboard (Auth → Rate Limits)
- [ ] Confirm `RESEND_API_KEY`, `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY` are set in Supabase Edge Function secrets (Dashboard → Project Settings → Edge Functions)
- [ ] Enable RLS audit log in Supabase Dashboard and verify no unexpected bypasses

### GDPR

- [ ] Confirm `anonymise-account` Edge Function deletes `questionnaire_responses` (migration 022 + code change in place)
- [ ] Confirm location consent CHECK constraint active (`025_location_consent_constraint.sql`)
- [ ] Verify Privacy Policy and Terms of Use links resolve correctly in the app
- [ ] Test full account deletion flow: sign up → complete questionnaire → delete account → confirm no PII rows remain

### Database

- [ ] Verify all migrations 001–025 applied in correct order on production Supabase
- [ ] Check `elo_history.match_id` index exists: `SELECT indexname FROM pg_indexes WHERE tablename='elo_history'`
- [ ] Check `notifications` unique dedup index exists: `SELECT indexname FROM pg_indexes WHERE tablename='notifications'`
- [ ] Check location consent constraint exists: `SELECT conname FROM pg_constraint WHERE conrelid='profiles'::regclass`
- [ ] Confirm `match-auto-confirm` and `request-expiry` cron jobs active: `SELECT jobname, schedule FROM cron.job`

### App Store / Play Store

- [ ] Update `pubspec.yaml` version + build number
- [ ] Update `CHANGELOG.md` with release notes
- [ ] Flutter build with production env: `flutter build ios --dart-define-from-file=.env.production`
- [ ] Flutter build with production env: `flutter build appbundle --dart-define-from-file=.env.production`
- [ ] TestFlight / Internal Track testing sign-off before public release

### Monitoring

- [ ] Set up Supabase alerts for Edge Function errors > 1% error rate
- [ ] Set up Supabase alerts for DB connections > 80% pool usage
- [ ] Verify Sentry or equivalent error tracking is configured (if used)

---

## Open Questions (Resolve Before Launch)

- [ ] **Q-02**: Finalise seed-ELO formula (currently placeholder)
- [ ] **Q-03**: Decide K-factor per tier (currently K=0.15 globally)
- [ ] **Q-06**: Define tournament withdrawal/walkover logic
- [ ] **Q-10**: Decide ELO decay enable/disable
- [ ] **CI/CD**: Create `.github/workflows/pr.yml` (flutter analyze + test on PR)
