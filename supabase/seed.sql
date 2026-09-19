-- ============================================================
-- RATED — Local seed data
-- Loaded automatically by `supabase start` (first run) and `supabase db reset`.
-- LOCAL ONLY: `supabase db push` never runs this file unless --include-seed is
-- passed. Never pass --include-seed against dev or prod.
--
-- Accounts (email / password):
--   alice@rated.test / password123
--   bob@rated.test   / password123
--
-- Profiles are created by handle_new_user (022) from the auth.users INSERT, so
-- this file only inserts auth rows and then adjusts the profiles.
--
-- Matches:
--   1. Confirmed — Alice beat Bob. Exercises trg_match_counters (028):
--      expected Alice 1 played / 1 won, Bob 1 played / 0 won.
--   2. Pending — Bob beat Alice, awaiting Alice's confirmation. Must NOT count
--      until confirmed; confirming it in the app should move both to 2 played.
-- ============================================================

-- ── Auth users ───────────────────────────────────────────────────────────────
-- Token columns are set to '' because GoTrue cannot scan NULL into them.

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'authenticated', 'authenticated', 'alice@rated.test',
   extensions.crypt('password123', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"display_name":"Alice Test"}',
   now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222',
   'authenticated', 'authenticated', 'bob@rated.test',
   extensions.crypt('password123', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"display_name":"Bob Test"}',
   now(), now(), '', '', '', '');

insert into auth.identities (
  id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
)
select gen_random_uuid(), u.id, u.id::text,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now(), now(), now()
  from auth.users u
 where u.id in ('11111111-1111-1111-1111-111111111111',
                '22222222-2222-2222-2222-222222222222');

-- ── Profiles ─────────────────────────────────────────────────────────────────
-- Skip the questionnaire prompt so both accounts land straight on the home screen.

update public.profiles
   set questionnaire_done = true
 where id in ('11111111-1111-1111-1111-111111111111',
              '22222222-2222-2222-2222-222222222222');

-- ── Matches ──────────────────────────────────────────────────────────────────

insert into public.match_results (
  id, submitter_id, winner_id, loser_id, score, match_type, status, played_at, confirmed_at
)
values
  ('aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',   -- submitted by Alice
   '11111111-1111-1111-1111-111111111111',   -- Alice won
   '22222222-2222-2222-2222-222222222222',
   '[{"winner":6,"loser":4},{"winner":6,"loser":3}]',
   'friendly', 'confirmed', current_date - 1, now()),
  ('aaaaaaaa-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222',   -- submitted by Bob
   '22222222-2222-2222-2222-222222222222',   -- Bob won
   '11111111-1111-1111-1111-111111111111',
   '[{"winner":7,"loser":5},{"winner":6,"loser":4}]',
   'friendly', 'pending', current_date, null);

-- In the cloud the elo-recalculate Edge Function does this on confirmation;
-- locally there is no webhook, so apply the confirmed match's ELO directly.
select public.apply_elo_changes('aaaaaaaa-0000-0000-0000-000000000001');
