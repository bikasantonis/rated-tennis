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

## 3. Initial Seed (Questionnaire v3)

New players complete a sport-history questionnaire after registration, and are asked to retake it whenever the question set changes. The answers go to the `seed-elo` Edge Function, which computes a seed rating, upserts a `questionnaire_responses` row, and sets `questionnaire_done = true` and `questionnaire_version` on the profile.

The algorithm lives in `supabase/functions/seed-elo/seed.ts` (pure, unit-tested by `seed_test.ts`); `index.ts` is transport, validation and persistence only. Question routing is mirrored in `lib/screens/questionnaire/questionnaire_flow.dart` — a question routed away there must not be required by `requiredFields` here.

**Arithmetic:** every base and modifier is a multiple of 0.05, and the whole computation runs in **integer hundredths**, converting to a decimal only at the end. In binary floating point `6.0 + 0.15` is `6.149999999999999`, which would round down to 6.1 instead of 6.2.

### Inputs

Nine questions, of which any one player sees six to nine. Two routing predicates decide:

```
tournamentsActive  = tournaments_last_3y = true
recreationalCohort = greek_experience = 'recreational'
                  AND international_experience IN ('none', 'recreational_intl')
credentialed       = NOT recreationalCohort
```

`credentialed` is the exact complement of `recreationalCohort`, so no answer combination falls through both branches or neither.

| Field | Type | Asked of |
|---|---|---|
| `date_of_birth` | ISO date | everyone — age gate 16–90 |
| `years_playing` | integer 0–80 | everyone |
| `play_frequency` | `rarely` / `monthly` / `weekly` / `multiple_weekly` | everyone |
| `greek_experience` | `recreational` / `national_u200` / `national_20_200` / `national_top20` | everyone |
| `international_experience` | `none` / `recreational_intl` / `junior_intl` / `professional_adult` / `us_college` | everyone |
| `junior_career_high_ranking` | integer > 0 | when `junior_intl` |
| `received_atp_wta_point` | boolean | when `professional_adult` |
| `us_college_division` | `division_1` / `division_2` / `division_3` / `naia` / `njcaa` | when `us_college` |
| `tournaments_last_3y` | boolean | everyone |
| `tournaments_per_year` | integer 1–100 | when `tournaments_last_3y` |
| `tournament_level` | `amateur` / `intermediate` / `age_category` / `master` / `open` (ascending) | when `tournaments_last_3y` |
| `other_sport` | `racket_sports` / `other_sports` / `none` | when `recreationalCohort` |

Fields the routing did not ask are nulled server-side (`pruneOffBranch`) before the upsert, so a stale client cannot write an answer to a question the player never saw, and a retaker who changed cohort does not keep their old branch's answers.

### Cohort A — credentialed

**Base credential.** When a player holds both a Greek and an international credential, the **higher base** wins. (v2's priority tree silently discarded the Greek answer for anyone with `junior_intl` or `professional_adult`.)

| Credential | Base |
|---|---|
| `professional_adult` + ATP/WTA point | 10.0 |
| `professional_adult`, no point | 9.0 |
| `junior_intl`, career high < 300 | 8.5 |
| `national_top20` | 8.5 |
| `junior_intl`, career high ≥ 300 | 8.0 |
| `national_20_200` | 8.0 |
| `us_college` `division_1` | 8.0 |
| `national_u200` | 7.5 |
| `us_college` `division_2` | 7.5 |
| `us_college` `division_3` / `naia` / `njcaa` | 7.0 |

**Age** — physical decline only. v2's steep per-credential bands are gone, because inactivity is now measured directly rather than proxied by age:

| Age | ≤ 39 | 40–49 | 50–59 | 60–69 | 70+ |
|---|---|---|---|---|---|
| Adj | 0 | −0.20 | −0.50 | −0.80 | −1.10 |

**Tournament activity.** `tournaments_last_3y = false` → **−1.00**. Otherwise volume + level:

| Per year | 1–2 | 3–5 | 6–11 | 12+ | | Level | amateur | intermediate | age_category | master | open |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Adj | −0.30 | −0.10 | +0.10 | +0.20 | | Adj | −0.30 | −0.10 | +0.10 | +0.20 | +0.40 |

**Frequency:** `rarely` −0.30 · `monthly` −0.15 · `weekly` 0 · `multiple_weekly` +0.15

**Bounds:** `clamp(result, max(6.0, base − 1.5), min(10.0, base + 0.3))`. The floor stops a lapsed credential sinking below an active lesser one; the ceiling stops activity alone promoting a player past the next credential tier.

### Cohort B — recreational

Capped at **7.5** overall. Two sub-branches, because what separates a non-competitor (longevity, how often they play) differs from what separates a competitor (standard, volume).

**B-i — `tournaments_last_3y = false`.** Base **6.00**, capped at **6.8**.

| Signal | Values |
|---|---|
| `years_playing` | <1 −0.60 · 1–2 −0.40 · 3–9 0 · 10–19 +0.15 · 20+ +0.25 |
| `play_frequency` | `rarely` −0.50 · `monthly` −0.25 · `weekly` 0 · `multiple_weekly` +0.20 |

**B-ii — `tournaments_last_3y = true`.** Base by level: `amateur` 6.30 · `intermediate` 6.60 · `age_category` 6.80 · `master` 7.00 · `open` 7.20.

| Signal | Values |
|---|---|
| `tournaments_per_year` | 1–2 0 · 3–5 +0.15 · 6–11 +0.30 · 12+ +0.40 |
| `years_playing` | <1 −0.40 · 1–2 −0.20 · 3–9 0 · 10–19 +0.10 · 20+ +0.20 |
| `play_frequency` | `rarely` −0.30 · `monthly` −0.15 · `weekly` 0 · `multiple_weekly` +0.15 |

Both sub-branches then add `other_sport` (`racket_sports` +0.20 · `other_sports` +0.10) and, for `recreational_intl`, **+0.30**.

**Cross-check ceilings** on B-ii, applied before the band clamp. Both are level-independent on purpose — capping only the upper rungs would let `intermediate` out-score `age_category` at the same volume:
- `years_playing < 2` → cap **6.0**
- `tournaments_per_year ≤ 2` → cap **6.8**

**Entering tournaments can never score below not entering them.** B-ii takes `max(itself, B-i)` for the same answers, which makes that structural rather than a coincidence the caps have to be tuned around: the absolute `years < 2` cap would otherwise put a beginner who competes below a beginner who does not.

**Finish (both cohorts):** `clamp(round(x, 1), 5.0, 10.0)`.

Ranges: cohort B spans **5.0–7.5** in 0.1 steps (v2 produced only 5.5, 6.0 and 6.5); cohort A spans **6.0–10.0**. They deliberately overlap on 6.0–7.5 — an active master-level amateur can tie a former `national_u200`, and a long-lapsed ex-college player can sit below both.

### Re-seeding and the match guard

`seed-elo` upserts on `player_id`, so retries and retakes never duplicate rows. The **rating** is applied with a filtered update:

```
UPDATE profiles SET elo_rating = <seed> WHERE id = <player> AND matches_played = 0
```

This closes the read-then-write race and doubles as the "did it apply" signal. A player with settled matches keeps their earned rating; their answers and `seed_elo` still update. `matches_played` is maintained by `trg_match_counters` (028) over `status IN ('confirmed','overridden')`.

Response: `{ seed_elo, rating_applied, current_elo, matches_played, questionnaire_version }`.

No `elo_history` row is written for a seed (`event_type` has no value for it, and v2 did not either). That is safe because a re-seed can only move the rating of a player with no matches, who therefore has no ledger and a null `peak_elo` — so a downward re-seed cannot leave a stale inflated peak.

### v2 request bodies (legacy)

A body without `questionnaire_version: 3` is treated as v2 and scored by `computeSeedEloV2`, a frozen verbatim copy of the pre-030 algorithm, writing `questionnaire_version = 2`. Cloudflare Pages serves a hashed bundle so open tabs keep running old JS, and the mobile builds are not force-updatable. `us_college_division` is normalised from the old display strings (`'Division I'` → `division_1`) on **every** path — without that, the first legacy submission after migration 030 would violate `qr_us_college_division_check`. See `docs/TODO.md` for the removal of this path.

The v2 algorithm, for reference: professional (+point, age ≤ 39 → 10.0, else 9.0) → junior international (ranking < 300: 8.5/8.0 by age ≤ 39; else 8.0/7.5) → Greek national (`national_top20` 8.5/8.0/7.5/7.0 at ages 30/45/55/56+; `national_20_200` 8.0/7.5/7.0 at 35/45/46+; `national_u200` 7.5/7.0 at 30/31+) → recreational (`recreational_intl` 6.5; college D1 7.0 else 6.5; racket sports 6.5; other sport 6.0; else years < 2 → 5.5, 2–5 → 6.0, > 5 → 6.5).

---

## 4. Match Confirmation Flow

```
Player A submits match result (winner + loser + score + format)
    ↓  INSERT into match_results (status = 'pending')
    ↓  trg_match_submission_rate_limit: max 20 submissions per hour
    ↓  trg_notify_match_submitted: notify opponent (NF-01)
Player B taps Confirm in Match Inbox
    ↓  app → functions.invoke('elo-recalculate', { match_id })
    ↓  Edge Function validates: caller is a participant but not the submitter; match still 'pending'
    ↓  UPDATE match_results SET status = 'confirmed', confirmed_at = now()
    ↓      trg_match_counters: matches_played / matches_won updated
    ↓  apply_elo_changes(match_id)     ← idempotent SQL function
    ↓  Both profiles updated atomically, elo_history rows appended
    ↓  app invalidates feed, inbox, profile and sparkline providers
```

If Player B **disputes** instead, the match enters `disputed` status and an admin resolves it in the Admin Panel: **approve** sets `status = 'confirmed'`, **override** sets `status = 'overridden'`. In both cases the app then calls the `apply_elo_changes` RPC directly. If the opponent never responds, the auto-confirm job confirms the match after 48 hours (§9).

---

## 5. Rating Calculation (`apply_elo_changes`)

Implemented as `public.apply_elo_changes(p_match_id uuid)` in PostgreSQL (`SECURITY DEFINER`, final definition in migration 019). Called by the `elo-recalculate` Edge Function, the auto-confirm cron job, and the admin dispute actions (client RPC). It does not check the match status or the caller — see [DATABASE.md §8.2](DATABASE.md#82-elo-can-be-applied-without-the-opponents-confirmation).

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

The match result itself is still recorded and visible in both players' history — only the ELO change is suppressed. A voided match **does** count toward `profiles.matches_played` / `matches_won` (migration 028), so Played always agrees with the match feed. The client can preview the void before submitting via `friendlyEloExcludedProvider` in `match_provider.dart`, and both the Home feed and the profile history render a `NotRatedChip` in place of the delta once the match is settled.

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

A pg_cron job (`match-auto-confirm`) runs every hour. It finds all `pending` match results whose `created_at` is more than 48 hours old, confirms them (`auto_confirmed = true`), calls `apply_elo_changes`, and sends NF-02 notifications to both players. Since migration 024, the update is guarded by `WHERE status = 'pending'` and the notification insert uses `ON CONFLICT DO NOTHING`, so overlapping runs cannot double-confirm or double-notify.

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
