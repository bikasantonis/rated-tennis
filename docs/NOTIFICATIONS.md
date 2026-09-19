# RATED — Notification System

This document describes how notifications are generated, delivered to devices, and routed within the app. The implementation spans DB triggers (`010_notification_triggers.sql`, `016_organizer_requests.sql`, `019_numeric_tiers.sql`), the `match-auto-confirm` pg_cron job, per-project Database Webhooks, three Edge Functions (`send-notification`, `send-email`, `notify-nearby-tournament`), and `lib/services/notification_service.dart`.

---

## Table of Contents

1. [Delivery Pipeline](#1-delivery-pipeline)
2. [Notification Types](#2-notification-types)
3. [In-App Notification Panel](#3-in-app-notification-panel)
4. [Deep-Link Routing](#4-deep-link-routing)
5. [Nearby Tournament Push](#5-nearby-tournament-push)
6. [Configuration](#6-configuration)

---

## 1. Delivery Pipeline

Every notification follows the same chain:

```
1. DB trigger, pg_cron job, or Edge Function
        ↓
2. INSERT into notifications table
        ↓
3. Database Webhooks on notifications INSERT fire:
     ├── send-notification  → OneSignal REST API → device push (APNs / FCM)
     └── send-email         → Resend (organizer_request_* types only)
```

**Why a `notifications` table as the hub?**
- Provides a persistent in-app notification panel with history
- One webhook on INSERT is the single integration point — no OneSignal calls inside trigger code
- The `is_read` column drives the unread badge count
- `reference_type` + `reference_id` enable deep-link routing (see §4)
- The panel works even when push is unavailable, since it reads directly from the table

**`send-notification`** reads `recipient_id`, `title`, `body`, `reference_type`, and `reference_id` from the inserted row and targets the device via OneSignal's `external_id` alias, which the app sets to the player's Supabase UUID at sign-in.

**Platform and environment limits:**
- **Push is native only.** `onesignal_flutter` has no web implementation, so `main.dart` skips OneSignal on web and `identifyUser` / `clearUser` are no-ops there. Web users (ratedtennis.gr) see notifications only in the in-app panel.
- **Webhooks are per-project Dashboard configuration**, not migrations. They must exist on each cloud project (see §6), and the local Docker stack has none, so local runs create notification rows but send no push or email.
- A partial unique index `(recipient_id, reference_id, type) WHERE reference_id IS NOT NULL` (migration 024) de-duplicates notifications for the same entity.

---

## 2. Notification Types

| Type string | NF code | Created by | Recipient | Email? |
|---|---|---|---|---|
| `match_submitted` | NF-01 | `trg_notify_match_submitted` on `match_results` INSERT | Non-submitting player | No |
| `match_auto_confirmed` | NF-02 | `match-auto-confirm` pg_cron job, after 48 h | Both players | No |
| `match_disputed` | NF-03 | `trg_notify_match_disputed` when `status → 'disputed'` | Original submitter | No |
| `match_request_received` | NF-04 | `trg_notify_match_request_received` on `match_requests` INSERT | Challenge recipient | No |
| `match_request_accepted` | NF-05 | `trg_notify_match_request_responded` when `status → 'accepted'` | Requester | No |
| `match_request_declined` | NF-05 | Same trigger, `status → 'declined'` | Requester | No |
| `match_elo_excluded` | — | `notify_match_excluded()`, called from `apply_elo_changes` | Both players | No |
| `nearby_tournament` | — | `notify-nearby-tournament` Edge Function (see §5) | Consenting players in range | No |
| `organizer_request_submitted` | — | `trg_organizer_request_submitted` on `organizer_requests` INSERT | All admins | Yes |
| `organizer_request_approved` | — | `trg_organizer_request_decided` when `status → 'approved'` | Requesting player | Yes |
| `organizer_request_denied` | — | `trg_organizer_request_decided` when `status → 'denied'` | Requesting player | Yes |

"Challenge" is the user-facing name for a match request; table and type names still say `match_request`.

**Not implemented yet** (PRD codes): NF-06 tournament registration confirmed, NF-07 tournament match scheduled, NF-08 tier promotion/demotion, NF-09 24-hour challenge-expiry warning, NF-10 weekly digest email. There are no per-type notification preferences; the only opt-in is the nearby-tournament toggle in Settings → Location. See [TODO.md](TODO.md).

---

## 3. In-App Notification Panel

`notificationPanelProvider` streams from the `notifications` table filtered to `recipient_id = current user`, ordered by `created_at DESC`. The stream uses Supabase Realtime, so new notifications appear without polling. This requires `notifications` to be in the `supabase_realtime` publication, which only happened in migration 029 — before it the stream delivered its initial snapshot only, and the bell badge changed only on a reload.

`NotificationPanel` (`lib/widgets/notification_panel.dart`) is a popup opened from the bell icon in `AppBarActions`. Opening it marks unread items as read (RLS allows recipients to update their own rows). The unread count for the bell badge is derived from the same stream. `match_elo_excluded` rows get a distinct `leaderboard_outlined` icon.

---

## 4. Deep-Link Routing

`NotificationService.resolveRoute()` maps `reference_type` + `reference_id` to a go_router path:

| `reference_type` | `reference_id` | Resolved path |
|---|---|---|
| `match_result` | any | `/matches` (Match Inbox) |
| `match_request` | any | `/matches` (Match Inbox) |
| `tournament` | `<tournament_id>` | `/tournaments/<id>` |
| `tournament` | null | `/tournaments` |
| `profile` | `<player_id>` | `/leaderboard/<id>` |
| `profile` | null | `/profile` |
| `organizer_request` | any | `/admin/disputes` |
| unknown / null | — | `/home` |

Both the push tap handler (app backgrounded or terminated) and the in-app panel tile tap call `resolveRoute()` and then `router.push(path)`.

`organizer_request` always routes to the admin panel — including the approved/denied notifications sent to the (non-admin) requesting player. The in-code comment intends those to go to Settings; this is tracked in TODO.md.

The `reference_type` strings in the DB are the same strings used here — changing one requires updating both.

---

## 5. Nearby Tournament Push

This flow is driven by a Database Webhook on the `tournaments` table rather than a SQL trigger:

1. The organiser moves a tournament to `status = 'registration_open'` (Organiser → tournament → Status Controls).
2. The `tournaments` UPDATE webhook calls `notify-nearby-tournament` with `record` and `old_record`.
3. The function continues only if the status has **just** become `registration_open` and the tournament has `venue_lat` / `venue_lng`; otherwise it returns `{ skipped: true }`.
4. It calls `nearby_tournament_notify_targets(tournament_id)`, which returns players with:
   - `location_consent = true`
   - `notify_nearby_tournaments = true`
   - `home_lat` / `home_lng` set
   - distance to the venue ≤ their `nearby_radius_km`
   - not the tournament organiser
5. It inserts one `nearby_tournament` notification per target, in batches of 50 (`reference_type = 'tournament'`, so a tap opens the tournament).
6. Each INSERT fires the standard `send-notification` webhook.

The function runs with the service role and never returns location data to the client. Direct invocation with a tournament row as the body also works (useful for testing).

**Why not OneSignal segments?** Per-player consent and per-player radius require per-row evaluation, which OneSignal filters cannot express.

---

## 6. Configuration

### SDK initialisation (native only)

```dart
// lib/main.dart — inside SentryFlutter.init's appRunner
if (!kIsWeb) {
  OneSignal.initialize(const String.fromEnvironment('ONESIGNAL_APP_ID'));
  OneSignal.Notifications.requestPermission(false); // iOS prompt; Android 13+ prompts on first notification
  NotificationService.instance.init();
}
```

### User identification

```dart
await NotificationService.instance.identifyUser(supabaseUserId); // → OneSignal.login(uid)
await NotificationService.instance.clearUser();                  // → OneSignal.logout() on sign-out
```

Linking the subscription to the Supabase UUID via `external_id` means notifications reach the right device regardless of reinstalls. After logout, pushes to that UUID no longer reach the device.

### Edge Function secrets (set on each Supabase project)

| Variable | Used by | Purpose |
|---|---|---|
| `ONESIGNAL_APP_ID` | `send-notification` | OneSignal app UUID |
| `ONESIGNAL_REST_API_KEY` | `send-notification` | REST API key for server-to-OneSignal calls |
| `RESEND_API_KEY` | `send-email` | Resend API key; if unset, the function no-ops |
| `FROM_EMAIL` | `send-email` | Sender, e.g. `RATED <noreply@yourdomain>`; defaults to `RATED <noreply@rated.app>` |

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically.

### Database Webhooks (Dashboard → Database → Webhooks, per project)

| Table | Event | Target function |
|---|---|---|
| `notifications` | INSERT | `send-notification` |
| `notifications` | INSERT | `send-email` |
| `tournaments` | UPDATE | `notify-nearby-tournament` |

`elo-recalculate` is called directly by the app with the user's JWT and a `match_id`; it needs no webhook.

### Platform setup

**Android:** upload the FCM credentials in the OneSignal dashboard (Settings → Push → Google Android). No `google-services.json` is needed in the Flutter app.

**iOS:** upload the APNs Auth Key (p8) in the OneSignal dashboard (Settings → Push → Apple iOS). OneSignal handles provisioning.

End-to-end push on a real device has not been signed off yet — see [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md).
