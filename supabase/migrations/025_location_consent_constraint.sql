-- Migration 025 — Enforce location consent at DB level
--
-- Without this constraint, a bug or malicious client could store home_lat/lng/city
-- even when location_consent = false, violating GDPR data minimisation.
-- The constraint makes it impossible to store coordinates without consent.

ALTER TABLE public.profiles
  ADD CONSTRAINT chk_location_consent_required
  CHECK (
    location_consent = true
    OR (home_lat IS NULL AND home_lng IS NULL AND home_city IS NULL)
  );
