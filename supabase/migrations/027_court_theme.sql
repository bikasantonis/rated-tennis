-- ── Add court_theme personalisation column ────────────────────────────────────
-- Stores the user's selected court background for the EloScoreCard.
-- Valid values: 'australian_open' | 'roland_garros' | 'wimbledon' | 'us_open' | 'club_classic'
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS court_theme TEXT NOT NULL DEFAULT 'roland_garros';
