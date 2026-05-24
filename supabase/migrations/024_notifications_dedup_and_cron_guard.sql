-- Migration 024 — Notification dedup + cron job hardening
--
-- Problem 1: notifications has no unique constraint, so if match-auto-confirm
--   runs concurrently (e.g. after a DB restart mid-job) it can insert duplicate
--   notification rows for the same match and recipient.
--
-- Problem 2: the auto-confirm UPDATE has no WHERE status check, so a second
--   concurrent run can re-set confirmed_at and re-insert notifications.
--
-- Fixes:
--   a. Partial unique index on (recipient_id, reference_id, type) for rows
--      where reference_id IS NOT NULL. Covers auto-confirm, friendly-void,
--      and all trigger-inserted notifications.
--   b. Recreate match-auto-confirm cron job with:
--        - WHERE status = 'pending' guard on the UPDATE (skip already-confirmed)
--        - INSERT … ON CONFLICT DO NOTHING on the notification insert


-- ── a. Dedup index ─────────────────────────────────────────────────────────────

CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_dedup
  ON public.notifications (recipient_id, reference_id, type)
  WHERE reference_id IS NOT NULL;


-- ── b. Recreate cron job with guards ──────────────────────────────────────────

-- Unschedule idempotently (fails silently if job doesn't exist yet on this DB)
DO $$
BEGIN
  PERFORM cron.unschedule('match-auto-confirm');
EXCEPTION WHEN others THEN NULL;
END;
$$;

SELECT cron.schedule(
  'match-auto-confirm',
  '0 * * * *',
  $cron$
    DO $inner$
    DECLARE v_id uuid;
    BEGIN
      FOR v_id IN
        SELECT id FROM public.match_results
        WHERE status = 'pending'
          AND created_at < now() - INTERVAL '48 hours'
      LOOP
        -- Guard: only update rows still in pending state (idempotent against overlap)
        UPDATE public.match_results
          SET status         = 'confirmed',
              auto_confirmed = true,
              confirmed_at   = now()
        WHERE id = v_id
          AND status = 'pending';

        -- Only run ELO changes if this run actually confirmed the match
        IF FOUND THEN
          PERFORM public.apply_elo_changes(v_id);

          -- NF-02: notify both players; ON CONFLICT covers any overlap duplicates
          INSERT INTO public.notifications
            (recipient_id, type, title, body, reference_id, reference_type)
          SELECT
            p.id,
            'match_auto_confirmed',
            'Match auto-confirmed',
            'A pending match result was automatically confirmed after 48 hours.',
            v_id,
            'match_result'
          FROM (
            SELECT winner_id AS id FROM public.match_results WHERE id = v_id
            UNION ALL
            SELECT loser_id  AS id FROM public.match_results WHERE id = v_id
          ) p
          ON CONFLICT (recipient_id, reference_id, type)
            WHERE reference_id IS NOT NULL
          DO NOTHING;
        END IF;
      END LOOP;
    END;
    $inner$ LANGUAGE plpgsql;
  $cron$
);
