-- Migration 008 — match format column
-- Adds the format column to match_results to support all 6 match formats.
-- Existing rows default to 'bo3_standard' (classic best-of-3 with 3rd deciding set).

ALTER TABLE match_results
  ADD COLUMN IF NOT EXISTS format text NOT NULL DEFAULT 'bo3_standard'
  CHECK (format IN (
    'bo3_standard',
    'bo3_super_tb',
    'bo3_mini_3rd',
    'bo3_mini_super',
    'one_full_set',
    'one_mini_set'
  ));

COMMENT ON COLUMN match_results.format IS
  'Match format: bo3_standard (3 full sets), bo3_super_tb (2 full + super TB), '
  'bo3_mini_3rd (3 mini-sets), bo3_mini_super (2 mini + super TB), '
  'one_full_set, one_mini_set. Default bo3_standard for historical rows.';
