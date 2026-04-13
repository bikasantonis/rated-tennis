-- ============================================================
-- RATED — Migration 006: Location features
-- Adds venue location to tournaments and home location (GDPR-gated)
-- to profiles, plus helper SQL functions for proximity queries.
-- ============================================================

-- ── tournaments: venue location (event data, not personal data) ───────────────
ALTER TABLE public.tournaments
  ADD COLUMN IF NOT EXISTS city       varchar(100),
  ADD COLUMN IF NOT EXISTS country    char(2),
  ADD COLUMN IF NOT EXISTS venue_lat  double precision,
  ADD COLUMN IF NOT EXISTS venue_lng  double precision;

-- ── profiles: home location (personal data, GDPR-gated) ──────────────────────
-- All columns nullable; populated only after explicit user consent.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS location_consent           boolean     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS location_consent_at        timestamptz,
  ADD COLUMN IF NOT EXISTS home_city                  varchar(100),
  ADD COLUMN IF NOT EXISTS home_lat                   double precision,
  ADD COLUMN IF NOT EXISTS home_lng                   double precision,
  ADD COLUMN IF NOT EXISTS notify_nearby_tournaments  boolean     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS nearby_radius_km           integer     NOT NULL DEFAULT 50
                                                        CHECK (nearby_radius_km IN (25, 50, 100, 150));

-- ── Haversine distance function (km) — no PostGIS extension needed ─────────────
CREATE OR REPLACE FUNCTION public.haversine_km(
  lat1 double precision,
  lng1 double precision,
  lat2 double precision,
  lng2 double precision
) RETURNS double precision AS $$
DECLARE
  r    double precision := 6371;
  dlat double precision := radians(lat2 - lat1);
  dlng double precision := radians(lng2 - lng1);
  a    double precision;
BEGIN
  a := sin(dlat / 2) ^ 2
       + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ^ 2;
  RETURN r * 2 * asin(sqrt(a));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ── nearby_tournaments RPC ────────────────────────────────────────────────────
-- Returns all tournaments whose venue is within p_radius_km of the given point,
-- ordered by ascending distance.  Called from Flutter with the user's lat/lng.
CREATE OR REPLACE FUNCTION public.nearby_tournaments(
  p_lat       double precision,
  p_lng       double precision,
  p_radius_km integer DEFAULT 50
) RETURNS TABLE (
  id                uuid,
  organizer_id      uuid,
  club_id           uuid,
  name              varchar,
  description       text,
  format            varchar,
  elo_min           integer,
  elo_max           integer,
  max_players       integer,
  registration_open boolean,
  starts_at         date,
  ends_at           date,
  status            varchar,
  elo_multiplier    numeric,
  city              varchar,
  country           char,
  venue_lat         double precision,
  venue_lng         double precision,
  created_at        timestamptz,
  updated_at        timestamptz,
  distance_km       double precision
) AS $$
  SELECT
    t.id, t.organizer_id, t.club_id, t.name, t.description,
    t.format, t.elo_min, t.elo_max, t.max_players, t.registration_open,
    t.starts_at, t.ends_at, t.status, t.elo_multiplier,
    t.city, t.country, t.venue_lat, t.venue_lng,
    t.created_at, t.updated_at,
    public.haversine_km(p_lat, p_lng, t.venue_lat, t.venue_lng) AS distance_km
  FROM public.tournaments t
  WHERE t.venue_lat IS NOT NULL
    AND t.venue_lng IS NOT NULL
    AND public.haversine_km(p_lat, p_lng, t.venue_lat, t.venue_lng) <= p_radius_km
  ORDER BY distance_km ASC;
$$ LANGUAGE SQL STABLE SECURITY INVOKER;

-- ── nearby_players RPC ────────────────────────────────────────────────────────
-- Returns public players who have opted into location sharing and are within
-- p_radius_km of the given point.
CREATE OR REPLACE FUNCTION public.nearby_players(
  p_lat       double precision,
  p_lng       double precision,
  p_radius_km integer DEFAULT 50,
  p_limit     integer DEFAULT 50,
  p_offset    integer DEFAULT 0
) RETURNS TABLE (
  id           uuid,
  display_name varchar,
  elo_rating   numeric,
  elo_tier     varchar,
  home_city    varchar,
  distance_km  double precision
) AS $$
  SELECT
    p.id,
    p.display_name,
    p.elo_rating,
    p.elo_tier,
    p.home_city,
    public.haversine_km(p_lat, p_lng, p.home_lat, p.home_lng) AS distance_km
  FROM public.profiles p
  WHERE p.location_consent = true
    AND p.is_public = true
    AND p.deleted_at IS NULL
    AND p.home_lat IS NOT NULL
    AND p.home_lng IS NOT NULL
    AND public.haversine_km(p_lat, p_lng, p.home_lat, p.home_lng) <= p_radius_km
  ORDER BY distance_km ASC
  LIMIT p_limit OFFSET p_offset;
$$ LANGUAGE SQL STABLE SECURITY INVOKER;

-- ── nearby_tournament_notify_targets ─────────────────────────────────────────
-- Used by the notify-nearby-tournament Edge Function to find which users
-- should receive a push notification when a tournament opens for registration.
CREATE OR REPLACE FUNCTION public.nearby_tournament_notify_targets(
  p_tournament_id uuid
) RETURNS TABLE (user_id uuid) AS $$
  SELECT p.id
  FROM public.profiles p
  JOIN public.tournaments t ON t.id = p_tournament_id
  WHERE p.location_consent           = true
    AND p.notify_nearby_tournaments  = true
    AND p.home_lat  IS NOT NULL
    AND p.home_lng  IS NOT NULL
    AND t.venue_lat IS NOT NULL
    AND t.venue_lng IS NOT NULL
    AND public.haversine_km(p.home_lat, p.home_lng, t.venue_lat, t.venue_lng)
          <= p.nearby_radius_km
    AND p.id <> t.organizer_id;   -- don't notify the organizer themselves
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- ── Indexes for distance queries ──────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_profiles_home_location
  ON public.profiles (home_lat, home_lng)
  WHERE home_lat IS NOT NULL AND home_lng IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tournaments_venue_location
  ON public.tournaments (venue_lat, venue_lng)
  WHERE venue_lat IS NOT NULL AND venue_lng IS NOT NULL;
