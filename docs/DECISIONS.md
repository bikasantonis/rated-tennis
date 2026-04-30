# RATED — Architecture Decision Records

Key choices made during design and development, with rationale and trade-offs. Append new records when significant decisions are made — include what was decided, why, and what was traded away.

---

## ADR-01: Supabase over Firebase

**Decision:** Use Supabase (PostgreSQL + PostgREST + Realtime) as the backend instead of Firebase (Firestore + Cloud Functions).

**Why:**
- **EU data residency.** Supabase runs on eu-central-1 (Frankfurt), satisfying GDPR's requirement that personal data stays within the EEA. Firebase does not guarantee EU-only data processing at the individual record level.
- **Relational schema.** Players, matches, ratings, and tournaments are deeply relational. PostgreSQL joins, transactions, generated columns, and foreign key constraints handle this naturally. Firestore's document model would require denormalisation and client-side joins.
- **Row-Level Security.** Supabase exposes PostgreSQL RLS directly to the client SDK. A single `is_admin()` helper function gates all admin writes. Firestore Security Rules cannot express multi-table role checks of the same complexity.
- **SQL migrations.** The `supabase/migrations/` directory provides a reproducible, reviewable, version-controlled schema history. Firestore has no equivalent.

**Trade-offs:** Supabase's ecosystem is smaller than Firebase's. Firebase-specific services (Remote Config, AdMob, Performance Monitoring) are not directly available.

---

## ADR-02: OneSignal over direct Firebase Cloud Messaging

**Decision:** Use OneSignal as the push notification provider rather than integrating FCM directly in the Flutter app.

**Why:**
- **No Firebase SDK in the app.** Removing Firebase eliminates the `google-services.json` / `GoogleService-Info.plist` credentials, the `firebase_core` package, and a source of EU data transfer via Google's infrastructure.
- **Unified APNs + FCM.** OneSignal handles both iOS APNs and Android FCM through a single integration. Direct FCM for iOS requires a separate APNs certificate upload and rotation cycle outside of OneSignal.
- **External ID targeting.** OneSignal's `external_id` alias (set to the player's Supabase UUID via `OneSignal.login()`) allows the `send-notification` Edge Function to target users by their application identity without maintaining a separate device token table in the database.
- **Dashboard analytics.** Per-notification delivery and open rates are available out of the box for debugging.

**Trade-offs:** OneSignal has a free tier with limits; above those limits it incurs cost. Direct FCM + APNs is free but requires more infrastructure and per-platform credential management.

---

## ADR-03: Server-side ELO calculation

**Decision:** ELO changes are calculated and applied inside a PostgreSQL function (`apply_elo_changes`), called by a Supabase Edge Function — not computed in the Flutter client.

**Why:**
- **Tamper prevention.** A client-side calculation could be manipulated by a modified APK or a web browser's developer tools to grant arbitrary rating changes. Moving the computation server-side makes this category of attack impossible.
- **Atomicity.** The PostgreSQL function acquires `SELECT FOR UPDATE` locks on both player profile rows, computes the delta, updates both ratings, and appends `elo_history` rows in a single transaction. This prevents race conditions when the same player's rating would be written concurrently from two separate match confirmations.
- **Idempotency.** The function exits immediately if `elo_history` rows for the match already exist. This makes it safe to re-trigger from webhook retries or manual admin actions.
- **Single source of truth.** The ELO formula, K-factor rules, delta clamp, and tier-gap void logic all live in one place (`supabase/migrations/019_numeric_tiers.sql`) rather than being duplicated in client code.

**Trade-offs:** Debugging ELO anomalies requires access to Supabase logs and the Edge Function runtime. The function cannot be unit-tested from the Flutter test suite — it needs its own PostgreSQL test environment.

---

## ADR-04: 5.0–10.0 ELO scale

**Decision:** Use a 5.0–10.0 numeric scale rather than the traditional 0–3000 chess ELO scale or a 1–10 scale.

**Why:**
- **Human-readable tiers.** The tier label is the rating number itself (e.g. "7.5"). Players understand immediately that 8.0 > 7.5 without needing a tier name lookup.
- **Alignment with existing systems.** The 5.0–10.0 range aligns loosely with established tennis rating systems familiar to the Greek tennis community (NTRP uses 1.0–7.0; ETN uses 1–10).
- **Proportional D divisor.** The standard ELO logistic divisor of 400 is proportional to the ~1200-unit practical range of chess ELO. For a 5-unit range, the proportional divisor is 400 × (5/1200) ≈ 1.67, which is what the `apply_elo_changes` function uses.
- **Avoids starting at zero.** Starting at 5.0 instead of 0 means new players cannot fall below a meaningful floor, and the displayed number is always positive and recognisable.

**Trade-offs:** The scale is non-standard, so ELO knowledge from chess or traditional sports does not directly transfer. Players must learn what "7.5" means in context.

---

## ADR-05: 11 numeric tiers instead of 6 named tiers

**Decision:** Replace the six named tiers (Beginner, Bronze, Silver, Gold, Platinum, Elite) with 11 numeric tiers at 0.5-point intervals (5.0, 5.5, 6.0, …, 10.0).

**Why:**
- **More frequent positive feedback.** A player advancing from 7.0 to 7.5 gains a visible tier promotion with only 0.5 ELO change. The previous 6-tier system required up to 1.5 ELO movement for a tier change, which could take many matches.
- **No subjective labels.** "Bronze" and "Silver" imply value judgements and are culturally loaded (Bronze = losing). Numeric tiers are neutral descriptors.
- **Tier label equals threshold.** No separate lookup table is needed in the UI. The tier name is the number; displaying it requires no string mapping beyond the enum.

**Trade-offs:** 11 distinct tier colours must be defined and maintained in `app_colors.dart`. The previous 6-colour scheme was simpler. All existing tier checks in the codebase required updating during migration 019.

---

## ADR-06: Riverpod 3 with code generation

**Decision:** Use Riverpod 3 with `@riverpod` annotations and `build_runner` code generation rather than Riverpod 2 manual provider declarations.

**Why:**
- **Type safety.** Code-generated providers eliminate the manual type parameter specifications that are error-prone in Riverpod 2 (`Provider<T>`, `StateNotifierProvider<N, S>`, etc.).
- **Static analysis.** `riverpod_lint` catches incorrect `ref.watch` vs `ref.read` usage at analysis time rather than at runtime — a common source of subtle bugs in Riverpod 2 apps.
- **Reduced boilerplate.** `@riverpod` generates the provider variable, the notifier class pattern, and `family` parameter handling. The resulting code reads more like plain Dart.

**Exception:** `authProvider` is a `ChangeNotifier` (not `@riverpod`) because it must be passed as `refreshListenable` to `GoRouter`, which requires a `Listenable`. `ChangeNotifier` implements `Listenable`; Riverpod's generated notifiers do not.

**Trade-offs:** `build_runner` must be re-run after any provider change. Generated `*.g.dart` files are excluded from git — a fresh clone requires `dart run build_runner build` before the app compiles.

---

## ADR-07: Freezed for data models

**Decision:** Use Freezed for all data models rather than writing `==`, `hashCode`, `copyWith`, `fromJson`, and `toJson` manually.

**Why:**
- **Immutability by construction.** Freezed models are structurally immutable — there is no way to accidentally mutate a shared instance.
- **`copyWith` correctness.** Freezed generates null-safe `copyWith` that handles nullable optional fields correctly, which is non-trivial to write manually.
- **Union types.** `@freezed` union types with `when` / `maybeWhen` pattern matching are used for discriminated state in providers.

**Trade-offs:** Requires `build_runner`. Any model field addition or change regenerates the `.freezed.dart` file, which can be noisy in PRs.

---

## ADR-08: go_router with ShellRoute for bottom navigation

**Decision:** Use go_router with `ShellRoute` rather than Flutter's raw `Navigator 2.0` API or `AutoRoute`.

**Why:**
- **URL-based routing is required for web.** Google OAuth's redirect URI must match a specific web URL (`localhost:3000`). go_router's declarative URL matching handles this correctly.
- **`ShellRoute` persistence.** The `BottomNavShell` scaffold persists across tab switches without rebuilding. Without `ShellRoute`, switching tabs tears down and rebuilds screens, losing scroll state.
- **`refreshListenable`.** go_router accepts `authProvider` as a `Listenable` and automatically re-evaluates redirect guards on every auth state change. No manual `context.go()` calls are needed after login/logout.
- **Official support.** go_router is maintained by the Flutter team; documentation and community support are strong.

**Trade-offs:** `ShellRoute` with nested routes is more complex to reason about than a simple `IndexedStack`. The redirect callback requires careful ordering (splash-ready check before auth check) to avoid redirect loops.

---

## ADR-09: Pure SQL haversine instead of PostGIS

**Decision:** Implement the haversine distance formula in plain SQL (migration 017) rather than enabling the PostGIS extension.

**Why:**
- **No extension dependency.** PostGIS requires explicit enabling on Supabase, adds to the local dev setup requirements, and may not be available on all Supabase plan tiers.
- **Sufficient accuracy.** Haversine is accurate to approximately 0.5% for distances under 500 km. For radii of 25–150 km with coordinates rounded to ~1 km precision, the error is indistinguishable from the coordinate imprecision itself.
- **No data type changes.** `double precision` latitude/longitude columns work without PostGIS geometry types or index types (`GIST`).

**Trade-offs:** PostGIS `GIST` spatial indexes would outperform plain `(home_lat, home_lng)` composite indexes at very large player counts. For the expected scale at launch, plain indexes are sufficient.

---

## ADR-10: Nominatim for reverse geocoding

**Decision:** Use Nominatim (OpenStreetMap Foundation) for converting GPS coordinates to a city name rather than Google Maps Geocoding API or Apple MapKit.

**Why:**
- **No API key or billing account required.** Google Maps Geocoding charges per request; Apple MapKit requires Apple Developer entitlements. Nominatim is free for reasonable usage.
- **EU infrastructure.** The OSM Foundation hosts Nominatim on European servers, consistent with GDPR data minimisation goals.
- **City-only output is sufficient.** The app only needs a city name, not a full formatted address. Nominatim's `addressdetails=1` response reliably provides this.

**Trade-offs:** Nominatim enforces a 1 req/s rate limit for anonymous usage. This is acceptable because geocoding only runs when the user explicitly enables location features in Settings — not on every app launch.

---

## ADR-11: ~1 km coordinate precision for stored location data

**Decision:** Round player GPS coordinates to approximately 1 km precision before sending them to the API and storing them in `profiles.home_lat/lng`.

**Why:**
- **GDPR Article 5(1)(c) — data minimisation.** Storing coordinates accurate to meters would effectively reveal a player's home address. 1 km precision is sufficient for tournament and player discovery but does not pinpoint a specific building or street.
- **Rounding on the client.** Coordinates are rounded in the Flutter app before the API call, so the server never receives high-precision data in the first place.

**Trade-offs:** Two players who live within 1 km of each other will appear at the same distance in the nearby-players list. This is acceptable for the discovery use case.

---

## ADR-12: UUID primary keys on all tables

**Decision:** All tables use `gen_random_uuid()` UUID primary keys rather than auto-incrementing integers.

**Why:**
- **No ID enumeration.** Sequential integer PKs allow a malicious client to iterate through all records by incrementing an ID. UUIDs (v4) are not guessable.
- **Client-side generation.** UUIDs can be generated in the Flutter app before the INSERT, enabling optimistic UI updates and offline-first scenarios without a database round-trip.
- **Merge safety.** If data from multiple environments (dev, staging, prod) is ever merged, UUID PKs have no collision risk. Integer sequences would need manual re-sequencing.

**Trade-offs:** UUIDs are 16 bytes vs 4 bytes for integers — slightly larger indexes and a minor query-speed cost. At the expected player scale this is negligible.

---

## ADR-13: Questionnaire v2 — sport history over self-assessment

**Decision:** Replace the original questionnaire (playing frequency, self-assessed level, preferred surface, has competed) with a sport-history questionnaire (Greek national ranking, international experience, age).

**Why (migration 021):**
- **Self-reported levels were unreliable.** "Advanced" means different things to different players. Two players who both select "Advanced" can easily be 1.5–2.0 ELO tiers apart.
- **Competitive history is objective.** Whether a player was ranked in the Greek top 20 is a verifiable fact with a clear ELO implication, regardless of how they self-assess.
- **Age adjustment is meaningful.** A former national top-20 player at 60 should seed lower than the same player at 30. The new algorithm accounts for age decline explicitly.

**Trade-offs:** Players with no competitive history (the recreational path) are harder to differentiate. The bottom tiers (5.0–6.5) will have more initial clustering. The `years_playing` field is retained as the primary differentiator for recreational players.
