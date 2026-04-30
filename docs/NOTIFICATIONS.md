# RATED — Notification System

This document describes how notifications are generated, delivered to devices, and routed within the app. The implementation spans DB triggers (`supabase/migrations/010_notification_triggers.sql`), a DB webhook, the `send-notification` Edge Function, and `lib/services/notification_service.dart`.

---

## Table of Contents

1. [Delivery Pipeline](#1-delivery-pipeline)
2. [Notification Types](#2-notification-types)
3. [In-App Notification Panel](#3-in-app-notification-panel)
4. [Deep-Link Routing](#4-deep-link-routing)
5. [Nearby Tournament Push (separate flow)](#5-nearby-tournament-push-separate-flow)
6. [OneSignal Configuration](#6-onesignal-configuration)

---

## 1. Delivery Pipeline

Every notification follows the same chain:

```
1. DB trigger  (or Edge Function / cron job)
        ↓
2. INSERT into notifications table
        ↓
3. Supabase DB webhook fires on INSERT
        ↓
4. send-notification Edge Function (Deno)
        ↓
5. OneSignal REST API  POST /notifications
        ↓
6. Device receives push (iOS APNs / Android FCM via OneSignal)
```

**Why a `notifications` table as the hub?**
- Provides a persistent in-app notification panel with history
- One DB webhook on INSERT is the single integration point — no per-trigger OneSignal calls in trigger code
- The `is_read` column drives the unread badge count
- `reference_type` + `reference_id` enable deep-link routing (see §4)
- The panel works even when push is disabled, since it reads directly from the table

**`send-notification` Edge Function** reads `title`, `body`, `reference_type`, and `reference_id` from the newly inserted row. It targets the device via OneSignal's `external_id` alias, which is set to the player's Supabase UUID at sign-in via `NotificationService.identifyUser()`.

---

## 2. Notification Types

| Type string | NF code | Triggering event | Recipient | Notes |
|---|---|---|---|---|
| `match_submitted` | NF-01 | `trg_notify_match_submitted` fires on `match_results INSERT` | Non-submitting player | Prompts them to confirm or dispute |
| `match_auto_confirmed` | NF-02 | `match-auto-confirm` cron job after 48 h | Both players | Match was confirmed automatically |
| `match_disputed` | NF-03 | `trg_notify_match_disputed` fires when `status → 'disputed'` | Original submitter | Tells them the opponent disputes their score |
| `match_request_received` | NF-04 | `trg_notify_match_request_received` fires on `match_requests INSERT` | Challenge recipient | |
| `match_request_accepted` | NF-05a | `trg_notify_match_request_responded` fires when `status → 'accepted'` | Requester | |
| `match_request_declined` | NF-05b | Same trigger, `status → 'declined'` | Requester | |
| `match_elo_excluded` | — | `notify_match_excluded()` called from `apply_elo_changes` | Both players | Friendly match voided due to tier gap > 1.5 |
| `nearby_tournament` | NF-06 | `notify-nearby-tournament` Edge Function when `registration_open → true` | Nearby consenting players | See §5 for this separate flow |
| `organizer_request_submitted` | — | DB trigger on `organizer_requests INSERT` | Admin users | Admin is notified of new requests |
| `organizer_request_approved` | — | DB trigger when request `status → 'approved'` | Requesting player | |
| `organizer_request_denied` | — | DB trigger when request `status → 'denied'` | Requesting player | |

NF-07 (tournament match results) and NF-08 (weekly digest) are deferred to post-Beta.

---

## 3. In-App Notification Panel

`notificationPanelProvider` streams from the `notifications` table filtered to `recipient_id = current_user.id`, ordered by `created_at DESC`. The stream uses Supabase Realtime so new notifications appear instantly without polling.

`NotificationPanel` (`lib/widgets/notification_panel.dart`) renders as a popup overlay triggered by the bell icon in `AppBarActions`. It lists the most recent notifications as tiles. Opening the panel marks all unread items as read in a single batch UPDATE.

The **unread count** (used for the bell badge) is derived from the same stream by counting rows where `is_read = false`.

---

## 4. Deep-Link Routing

The `notifications.reference_type` and `notifications.reference_id` columns provide a generic routing key. `NotificationService.resolveRoute()` maps them to go_router paths:

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

Both the **notification tap handler** (push notification when app is backgrounded or terminated) and the **in-app panel tile tap** call `resolveRoute()`. The resulting path is pushed via `router.push(path)`.

The `reference_type` strings in the DB are the same strings used in both places — changing one requires updating both.

---

## 5. Nearby Tournament Push (separate flow)

When a tournament's `registration_open` is set to `true`, the `notify-nearby-tournament` Edge Function is invoked. It does not go through the standard per-event trigger chain.

**Flow:**
1. Organiser sets `registration_open = true` on a tournament
2. Flutter calls the `notify-nearby-tournament` Edge Function with the `tournament_id`
3. The function calls `nearby_tournament_notify_targets(tournament_id)` — a SQL function that returns player UUIDs matching all of:
   - `location_consent = true`
   - `notify_nearby_tournaments = true`
   - `home_lat` / `home_lng` are set
   - Distance to `tournament.venue_lat/lng` ≤ player's `nearby_radius_km`
   - Player is not the tournament organiser
4. For each target, the function inserts a `nearby_tournament` notification row into `notifications`
5. Each INSERT fires the standard DB webhook → `send-notification` → OneSignal chain

**Why not use OneSignal segments for bulk targeting?**
Player-specific consent and per-player radius preferences require per-row evaluation. OneSignal filter segments cannot express per-user radius differences.

---

## 6. OneSignal Configuration

### SDK initialisation

```dart
// lib/main.dart — called before runApp
OneSignal.initialize(const String.fromEnvironment('ONESIGNAL_APP_ID'));
OneSignal.Notifications.requestPermission(false); // false = don't force-prompt on Android
NotificationService.instance.init();
```

`requestPermission(false)` shows the iOS system permission dialog without force-requesting it — the user sees it once at startup.

### User identification

```dart
// Called after Supabase sign-in succeeds
await NotificationService.instance.identifyUser(supabaseUserId);
// → OneSignal.login(supabaseUserId)
```

This links the device's OneSignal subscription to the Supabase UUID via the `external_id` alias. The `send-notification` Edge Function targets by this `external_id`, so notifications always reach the correct device regardless of the physical device or reinstalls.

### User de-identification

```dart
// Called on sign-out
await NotificationService.instance.clearUser();
// → OneSignal.logout()
```

After logout, the device subscription is no longer associated with any user. Push notifications sent to that UUID will not reach the device.

### Edge Function environment variables

Set these in the Supabase Edge Function secrets panel:

| Variable | Used by | Purpose |
|---|---|---|
| `ONESIGNAL_APP_ID` | `send-notification` | OneSignal app UUID |
| `ONESIGNAL_REST_API_KEY` | `send-notification` | REST API key for server-to-OneSignal calls |

### Platform setup

**Android:** Upload the FCM server key in the OneSignal dashboard (Settings → Push → Google Android). OneSignal uses this to route through FCM. No `google-services.json` is required in the Flutter app.

**iOS:** Upload the APNs Auth Key (p8 file) in the OneSignal dashboard (Settings → Push → Apple iOS). OneSignal handles certificate provisioning and rotation — no manual certificate management is needed.
