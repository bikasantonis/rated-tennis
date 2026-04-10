-- ============================================================
-- RATED — Migration 005: Edge Function configuration stubs
-- Actual function code lives in supabase/functions/
-- This migration documents the webhook bindings.
-- ============================================================

-- NOTE: The following Edge Functions are deployed separately via
--   supabase functions deploy <name>
-- and triggered as documented below.

-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ elo-recalculate                                                         │
-- │ Trigger: Database Webhook on match_results UPDATE where status →        │
-- │          'confirmed' or 'overridden'                                    │
-- │ Action:  Reads winner_id, loser_id, match_type, elo_multiplier.         │
-- │          Computes ELO deltas using K-factor per tier (default K=32).    │
-- │          Writes 2 rows to elo_history and updates profiles.elo_rating   │
-- │          in a single serializable transaction (SELECT FOR UPDATE).      │
-- │ Idempotent: guards on existing elo_history rows for same match_id.      │
-- └─────────────────────────────────────────────────────────────────────────┘

-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ match-auto-confirm                                                      │
-- │ Trigger: Supabase cron — every hour                                    │
-- │ Action:  Sets status = 'confirmed', auto_confirmed = true,             │
-- │          confirmed_at = now() for match_results where                  │
-- │          status = 'pending' and created_at < now() - interval '48h'   │
-- └─────────────────────────────────────────────────────────────────────────┘

-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ request-expiry                                                          │
-- │ Trigger: Supabase cron — every hour                                    │
-- │ Action:  Sets status = 'expired' for match_requests where              │
-- │          status = 'pending' and expires_at < now()                     │
-- └─────────────────────────────────────────────────────────────────────────┘

-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ seed-elo                                                                │
-- │ Trigger: HTTP POST (called after questionnaire_responses INSERT)       │
-- │ Action:  Computes seed ELO from questionnaire answers.                 │
-- │          TODO Q-02: finalise weighting formula before beta.             │
-- │          Placeholder: linear mapping 400–1200 based on level+frequency.│
-- └─────────────────────────────────────────────────────────────────────────┘

-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ elo-decay (disabled by default — TODO Q-10)                            │
-- │ Trigger: Supabase cron — daily at 02:00 UTC                            │
-- │ Action:  Applies mild ELO decay for players inactive > 60 days.        │
-- │          Enable via admin flag once user base is sufficient.            │
-- └─────────────────────────────────────────────────────────────────────────┘

-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ send-notification                                                       │
-- │ Trigger: Database Webhook on notifications INSERT                       │
-- │ Action:  Reads recipient_id, title, body, reference_type, reference_id  │
-- │          Calls OneSignal REST API POST /notifications with              │
-- │            include_aliases.external_id = [recipient_id]                 │
-- │            headings/contents from the notification row                  │
-- │            data.reference_type + data.reference_id for deep-link tap   │
-- │ Auth:    Uses ONESIGNAL_APP_ID + ONESIGNAL_REST_API_KEY from vault      │
-- └─────────────────────────────────────────────────────────────────────────┘

comment on table public.match_results is
  'ELO recalculation is triggered by a Supabase Database Webhook on UPDATE '
  'where status transitions to confirmed or overridden. '
  'See supabase/functions/elo-recalculate/index.ts';

comment on table public.notifications is
  'Push delivery is handled by the send-notification Edge Function triggered '
  'on INSERT. Uses OneSignal REST API with external_id = profiles.id (uuid). '
  'See supabase/functions/send-notification/index.ts';
