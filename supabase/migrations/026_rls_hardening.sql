-- Migration 026 — RLS hardening
--
-- Fix 1: Scope organizer match visibility to their own tournaments only.
--   Before: is_organizer_or_admin() could read every match in the system.
--   After:  organizers can only see matches belonging to tournaments they own.
--
-- Fix 2: Explicit DENY policies on questionnaire_responses for DELETE and UPDATE.
--   Questionnaire data is intended to be immutable after submission.
--   Without explicit policies, the absence of DELETE/UPDATE rules is implicit
--   denial, but makes the intent invisible to future reviewers.


-- ── Fix 1: match_results organizer visibility ─────────────────────────────────

DROP POLICY IF EXISTS "match_results_select" ON public.match_results;

CREATE POLICY "match_results_select"
  ON public.match_results FOR SELECT
  USING (
    winner_id    = auth.uid()
    OR loser_id  = auth.uid()
    OR submitter_id = auth.uid()
    OR is_admin()
    OR (
      -- Organizers may only see matches tied to their own tournaments
      is_organizer_or_admin()
      AND tournament_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = match_results.tournament_id
          AND t.organizer_id = auth.uid()
      )
    )
  );


-- ── Fix 2: Explicit deny on questionnaire_responses ───────────────────────────

CREATE POLICY "questionnaire_no_delete"
  ON public.questionnaire_responses FOR DELETE
  USING (false);

CREATE POLICY "questionnaire_no_update"
  ON public.questionnaire_responses FOR UPDATE
  USING (false);
