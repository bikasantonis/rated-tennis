# RATED — ELO Rating System

This document covers the full rating model: scale, tiers, initial seed, match rating logic, special cases, and the RATED prestige system. The authoritative implementation lives in `supabase/functions/seed-elo/index.ts` (seeding) and the `apply_elo_changes` PostgreSQL function (migration 019).

---

## Table of Contents

1. [Scale & Storage](#1-scale--storage)
2. [Tiers](#2-tiers)
3. [Initial Seed (Questionnaire)](#3-initial-seed-questionnaire)
4. [Match Confirmation Flow](#4-match-confirmation-flow)
5. [Rating Calculation (`apply_elo_changes`)](#5-rating-calculation-apply_elo_changes)
6. [Friendly Match Void](#6-friendly-match-void)
7. [Delta Bounds](#7-delta-bounds)
8. [RATED Prestige (Tier 10.0)](#8-rated-prestige-tier-100)
9. [Auto-Confirmation](#9-auto-confirmation)
10. [ELO History Ledger](#10-elo-history-ledger)

---

## 1. Scale & Storage

| Property | Value |
|---|---|
| Scale | 5.0 – 10.0 |
| DB storage | `numeric(8,4)` — four decimal places |
| Display | Rounded to 1 decimal place (`round(elo_rating, 1)`) |
| Min / max | 5.0 / 10.0; clamped at both bounds |

The four-decimal-place precision accumulates silently. The display layer rounds to one decimal, so a player at 7.0499 shows as 7.0, and at 7.0500 shows as 7.1. This prevents the leaderboard from jumping around on every small match.

The `profiles.elo_rating` column is denormalised (not a view) to allow O(1) leaderboard queries.

---

## 2. Tiers

11 numeric tiers at 0.5-point intervals. The tier label is the numeric threshold itself — no separate lookup table needed.

| Enum value | Threshold | Displayed label |
|---|---|---|
| `tier50` | ≥ 5.0 | 5.0 |
| `tier55` | ≥ 5.5 | 5.5 |
| `tier60` | ≥ 6.0 | 6.0 |
| `tier65` | ≥ 6.5 | 6.5 |
| `tier70` | ≥ 7.0 | 7.0 |
| `tier75` | ≥ 7.5 | 7.5 |
| `tier80` | ≥ 8.0 | 8.0 |
| `tier85` | ≥ 8.5 | 8.5 |
| `tier90` | ≥ 9.0 | 9.0 |
| `tier95` | ≥ 9.5 | 9.5 |
| `tier100` | ≥ 10.0 | 10.0 (RATED) |

**Tier sync is automatic.** The PostgreSQL trigger `trg_profiles_sync_elo_tier` fires `BEFORE INSERT OR UPDATE OF elo_rating` and writes the correct tier string within the same transaction. The Flutter `EloTier.fromRating()` factory mirrors this logic for client-side display without a round-trip.

Tier badge colours are defined in `lib/theme/app_colors.dart`.

---

## 3. Initial Seed (Questionnaire)

New players complete a sport-history questionnaire after registration. The answers are sent to the `seed-elo` Edge Function, which computes an initial rating, writes a `questionnaire_responses` row, and sets `questionnaire_done = true` on the profile.

### Inputs

| Field | Type | Description |
|---|---|---|
| `date_of_birth` | ISO date | Used to compute current age |
| `years_playing` | integer 0–80 | Years of tennis experience |
| `greek_experience` | enum | `recreational` / `national_u200` / `national_20_200` / `national_top20` |
| `international_experience` | enum | `none` / `recreational_intl` / `junior_intl` / `professional_adult` / `us_college` |
| `junior_career_high_ranking` | integer? | Required when `junior_intl` — career high ranking number |
| `received_atp_wta_point` | boolean? | Required when `professional_adult` |
| `us_college_division` | string? | Required when `us_college` |
| `other_sport` | enum? | `racket_sports` / `other_sports` / `none` — only collected when `greek_experience = recreational` |

### Seed Algorithm (evaluated in priority order)

**Priority 1 — Professional international**
- Received ATP/WTA point AND age ≤ 39 → **10.0**
- Professional, no ATP/WTA point (or age > 39) → **9.0**

**Priority 2 — Junior international**
- Career high ranking < 300 AND age ≤ 39 → **8.5**
- Career high ranking < 300 AND age > 39 → **8.0**
- Career high ranking ≥ 300 AND age ≤ 39 → **8.0**
- Career high ranking ≥ 300 AND age > 39 → **7.5**

**Priority 3 — Greek national competitive**
- `national_top20`: age ≤ 30 → **8.5** / age ≤ 45 → **8.0** / age ≤ 55 → **7.5** / 56+ → **7.0**
- `national_20_200`: age ≤ 35 → **8.0** / age ≤ 45 → **7.5** / 46+ → **7.0**
- `national_u200`: age ≤ 30 → **7.5** / 31+ → **7.0**

**Priority 4 — Recreational path** (reached when `greek_experience = recreational`)
- `recreational_intl` international experience → **6.5**
- US College Division I → **7.0**; other divisions → **6.5**
- Background in racket sports → **6.5**
- Background in other sport → **6.0**
- Pure recreational, years < 2 → **5.5**; years 2–5 → **6.0**; years > 5 → **6.5**

The `seed-elo` Edge Function uses upsert on `questionnaire_responses` (keyed on `player_id`), making the call safe to retry without creating duplicate rows.

---

## 4. Match Confirmation Flow

```
Player A submits match result (winner + loser + score)
    ↓  INSERT into match_results (status = 'pending')
    ↓  DB trigger: notify opponent (NF-01 push)
Player B taps Confirm in Match Inbox
    ↓  Flutter POSTs to /elo-recalculate  { match_id }
    ↓  Edge Function validates: JWT caller must be non-submitter
    ↓  UPDATE match_results SET status = 'confirmed', confirmed_at = now()
    ↓  CALL apply_elo_changes(match_id)     ← idempotent SQL function
    ↓  Both profiles updated atomically, elo_history rows appended
```

If Player B **disputes** instead, the match enters `disputed` status and an admin resolves it via the Admin Panel. Admin override sets `status = 'overridden'` and also triggers `apply_elo_changes`.

---

## 5. Rating Calculation (`apply_elo_changes`)

Implemented as `public.apply_elo_changes(p_match_id uuid)` in PostgreSQL (`SECURITY DEFINER`). Called by the `elo-recalculate` Edge Function and by the auto-confirm cron job.

### K-factor

```
K_friendly    = 0.15
K_tournament  = 0.15 × LEAST(tournament.elo_multiplier, 1.5)
```

Tournament multipliers are set per tournament in the range 1.0–1.5. The 1.5× cap means K is at most **0.225** for any match.

### ELO Formula

A modified logistic function with divisor D = 1.67. This is proportional to the standard 400 divisor scaled for the 5-unit range (5.0–10.0) vs the traditional ~1200-unit practical range.

```
E_winner = 1 / (1 + 10 ^ ((elo_loser − elo_winner) / 1.67))
raw_delta = K × (1 − E_winner)
delta     = CLAMP(raw_delta, 0.01, 0.20)

new_winner_elo = CLAMP(winner_elo + delta, 5.0, 10.0)
new_loser_elo  = CLAMP(loser_elo  − delta, 5.0, 10.0)
```

### Row Locking

Both `profiles` rows are `SELECT FOR UPDATE` locked before any reads. This prevents concurrent rating corruption when two matches involving the same player are confirmed simultaneously.

### Idempotency Guard

The function exits immediately if `elo_history` rows already exist for the given `match_id`. This makes it safe to re-trigger from webhook retries or manual admin actions without double-counting ratings.

---

## 6. Friendly Match Void

If a non-tournament match has a tier gap greater than **1.5 steps** between the two players, the match is **ELO-excluded** — no rating change occurs for either player.

**How the tier gap is computed:**
```sql
tier_floor = floor(elo_rating / 0.5) * 0.5
-- Example: 8.9900 → floor(17.98) × 0.5 = 8.5
-- Example: 7.0100 → floor(14.02) × 0.5 = 7.0
```

If `|winner_tier_floor − loser_tier_floor| > 1.5`, the match is voided:
- `match_results.elo_excluded` is set to `true`
- Both players receive a `match_elo_excluded` notification

A gap of exactly 1.5 is **allowed** (strict `>` comparison). Tournament matches are **never** voided regardless of tier gap.

The match result itself is still recorded and visible in both players' history — only the ELO change is suppressed. The client can preview this before submitting via `friendlyEloExcludedProvider` in `match_provider.dart`.

**Rationale:** Prevents a high-rated player from farming easy wins against much weaker opponents for ELO gain in friendly matches.

---

## 7. Delta Bounds

```
delta = GREATEST(0.01, LEAST(0.20, K × (1 − E_winner)))
```

**Floor 0.01:** Even a heavy favourite beating a much weaker opponent (e.g. in a tournament) gains at least 0.01. Prevents the case where a strong player chickens out of tournaments because the expected gain rounds to zero.

**Ceiling 0.20:** Limits extreme upsets in high-multiplier tournaments. Without this, a massive underdog beating a RATED player could jump an unrealistically large amount in one match.

---

## 8. RATED Prestige (Tier 10.0)

When a player's `elo_rating` reaches **10.0**, they enter the "RATED" tier. The `elo_rating` column stays at 10.0, but a separate `profiles.prestige_score` column accumulates.

**RATED vs. non-RATED match:**
- The non-RATED player uses the standard ELO formula, treating the RATED player as exactly 10.0
- The RATED player's `elo_rating` does not change; only `prestige_score` moves by ±delta

**RATED vs. RATED match:**
- Both players' effective ratings are `10.0 + prestige_score`, so differences between RATED players remain meaningful

**Entering RATED:** When a player first reaches 10.0, `prestige_score` is initialised to 0.

**Losing ground:** If a RATED player loses repeatedly to non-RATED opponents, their `prestige_score` decreases. The `elo_rating` stays at 10.0, but their relative standing among RATED players falls.

---

## 9. Auto-Confirmation

A pg_cron job (`match-auto-confirm`) runs every hour. It finds all `pending` match results older than 48 hours, confirms them (`auto_confirmed = true`), calls `apply_elo_changes`, and sends NF-02 notifications to both players.

This prevents indefinitely unconfirmed matches when the opponent is unresponsive.

---

## 10. ELO History Ledger

Every confirmed match appends two rows to `elo_history` (one per player):

| Column | Winner row | Loser row |
|---|---|---|
| `player_id` | winner's UUID | loser's UUID |
| `match_id` | same match | same match |
| `elo_before` | rating before | rating before |
| `elo_after` | rating after | rating after |
| `delta` | `+delta` (gain) | `−delta` (loss) |
| `event_type` | `'match'` | `'match'` |

The `delta` column is a PostgreSQL generated column (`GENERATED ALWAYS AS (elo_after − elo_before) STORED`) — it can never disagree with the two component values.

`elo_history` is append-only: no row is ever updated or deleted. The ELO sparkline on the player profile screen is built from this table.
