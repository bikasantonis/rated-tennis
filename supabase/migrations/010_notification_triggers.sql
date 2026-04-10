-- Migration 010 — Notification triggers (NF-01, NF-03, NF-04, NF-05)
--
-- Each trigger inserts a row into `notifications`.
-- The DB webhook on notifications INSERT fires send-notification (Edge Function)
-- which calls the OneSignal REST API to deliver the push.
--
-- NF-02 (auto-confirm 48h) is handled by the match-auto-confirm cron function — not here.
-- NF-06 / NF-07 (tournament) deferred to post-Beta.

-- ── Helper: get display_name for a player ────────────────────────────────────

CREATE OR REPLACE FUNCTION get_display_name(p_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT display_name FROM public.profiles WHERE id = p_id;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- NF-01: Match result submitted — notify the opponent (non-submitter)
-- Fires on INSERT into match_results.
-- Recipient = the player who did NOT submit (winner or loser that isn't submitter_id).
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION notify_match_submitted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_recipient  uuid;
  v_submitter_name text;
BEGIN
  -- The non-submitter is whichever of winner/loser is not the submitter.
  v_recipient := CASE
    WHEN NEW.winner_id <> NEW.submitter_id THEN NEW.winner_id
    ELSE NEW.loser_id
  END;

  v_submitter_name := get_display_name(NEW.submitter_id);

  INSERT INTO public.notifications
    (recipient_id, type, title, body, reference_id, reference_type)
  VALUES (
    v_recipient,
    'match_submitted',
    'Match result pending',
    v_submitter_name || ' submitted a match result. Please confirm or dispute.',
    NEW.id,
    'match_result'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_match_submitted ON public.match_results;

CREATE TRIGGER trg_notify_match_submitted
  AFTER INSERT ON public.match_results
  FOR EACH ROW
  EXECUTE FUNCTION notify_match_submitted();

-- ─────────────────────────────────────────────────────────────────────────────
-- NF-03: Match result disputed — notify the original submitter
-- Fires on UPDATE when status changes to 'disputed'.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION notify_match_disputed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_disputer_name text;
BEGIN
  -- Only fire when transitioning into 'disputed'
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;
  IF NEW.status <> 'disputed' THEN
    RETURN NEW;
  END IF;

  v_disputer_name := get_display_name(NEW.disputed_by);

  INSERT INTO public.notifications
    (recipient_id, type, title, body, reference_id, reference_type)
  VALUES (
    NEW.submitter_id,
    'match_disputed',
    'Match result disputed',
    v_disputer_name || ' has disputed your match result. Check your inbox.',
    NEW.id,
    'match_result'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_match_disputed ON public.match_results;

CREATE TRIGGER trg_notify_match_disputed
  AFTER UPDATE OF status ON public.match_results
  FOR EACH ROW
  EXECUTE FUNCTION notify_match_disputed();

-- ─────────────────────────────────────────────────────────────────────────────
-- NF-04: Match request received — notify the recipient
-- Fires on INSERT into match_requests.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION notify_match_request_received()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_requester_name text;
BEGIN
  v_requester_name := get_display_name(NEW.requester_id);

  INSERT INTO public.notifications
    (recipient_id, type, title, body, reference_id, reference_type)
  VALUES (
    NEW.recipient_id,
    'match_request_received',
    'New match request',
    v_requester_name || ' wants to schedule a match with you.',
    NEW.id,
    'match_request'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_match_request_received ON public.match_requests;

CREATE TRIGGER trg_notify_match_request_received
  AFTER INSERT ON public.match_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_match_request_received();

-- ─────────────────────────────────────────────────────────────────────────────
-- NF-05: Match request accepted or declined — notify the requester
-- Fires on UPDATE when status changes to 'accepted' or 'declined'.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION notify_match_request_responded()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_recipient_name text;
  v_title          text;
  v_body           text;
BEGIN
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;
  IF NEW.status NOT IN ('accepted', 'declined') THEN
    RETURN NEW;
  END IF;

  v_recipient_name := get_display_name(NEW.recipient_id);

  IF NEW.status = 'accepted' THEN
    v_title := 'Match request accepted';
    v_body  := v_recipient_name || ' accepted your match request. Time to play!';
  ELSE
    v_title := 'Match request declined';
    v_body  := v_recipient_name || ' declined your match request.';
  END IF;

  INSERT INTO public.notifications
    (recipient_id, type, title, body, reference_id, reference_type)
  VALUES (
    NEW.requester_id,
    'match_request_' || NEW.status,
    v_title,
    v_body,
    NEW.id,
    'match_request'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_match_request_responded ON public.match_requests;

CREATE TRIGGER trg_notify_match_request_responded
  AFTER UPDATE OF status ON public.match_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_match_request_responded();
