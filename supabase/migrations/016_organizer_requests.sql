-- 016_organizer_requests.sql
-- Self-service flow: players request organiser rights → admins approve/deny.
-- Approval is handled entirely in DB via triggers:
--   INSERT  → notify all admins (push + email via webhooks)
--   UPDATE  → update profiles.role if approved + notify the player

-- ── Table ────────────────────────────────────────────────────────────────────

create table if not exists public.organizer_requests (
  id          uuid        primary key default gen_random_uuid(),
  player_id   uuid        not null references public.profiles(id) on delete cascade,
  status      varchar(20) not null default 'pending'
              check (status in ('pending', 'approved', 'denied')),
  message     text,
  decided_by  uuid        references public.profiles(id),
  decided_at  timestamptz,
  created_at  timestamptz not null default now()
);

-- Only one PENDING request per player at a time (can re-request after denial).
create unique index uq_organizer_request_pending
  on public.organizer_requests(player_id)
  where (status = 'pending');

create index idx_organizer_requests_status
  on public.organizer_requests(status);

-- ── RLS ──────────────────────────────────────────────────────────────────────

alter table public.organizer_requests enable row level security;

-- Players can read their own requests; admins can read all.
create policy "org_req_select"
  on public.organizer_requests for select
  to authenticated
  using (player_id = auth.uid() or public.is_admin());

-- Players can submit requests for themselves only.
create policy "org_req_insert"
  on public.organizer_requests for insert
  to authenticated
  with check (player_id = auth.uid());

-- Only admins can decide (update status, decided_by, decided_at).
create policy "org_req_update_admin"
  on public.organizer_requests for update
  to authenticated
  using (public.is_admin());

-- ── Trigger: notify all admins on new request ─────────────────────────────────

create or replace function public.notify_admins_organizer_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  select display_name into v_name
  from public.profiles
  where id = NEW.player_id;

  insert into public.notifications
    (recipient_id, type, title, body, reference_id, reference_type)
  select
    p.id,
    'organizer_request_submitted',
    'New Organiser Request',
    coalesce(v_name, 'A player') || ' has requested organiser rights.',
    NEW.id,
    'organizer_request'
  from public.profiles p
  where p.role = 'admin';

  return NEW;
end;
$$;

create trigger trg_organizer_request_submitted
  after insert on public.organizer_requests
  for each row execute function public.notify_admins_organizer_request();

-- ── Trigger: update role + notify player on admin decision ────────────────────

create or replace function public.handle_organizer_request_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Only act when status actually changes.
  if NEW.status = OLD.status then
    return NEW;
  end if;

  if NEW.status = 'approved' then
    -- Grant the role.
    update public.profiles
    set role = 'organizer'
    where id = NEW.player_id;

    insert into public.notifications
      (recipient_id, type, title, body, reference_id, reference_type)
    values (
      NEW.player_id,
      'organizer_request_approved',
      'Organiser Rights Granted',
      'Your request was approved — you can now create and manage tournaments!',
      NEW.id,
      'organizer_request'
    );

  elsif NEW.status = 'denied' then
    insert into public.notifications
      (recipient_id, type, title, body, reference_id, reference_type)
    values (
      NEW.player_id,
      'organizer_request_denied',
      'Organiser Request Declined',
      'Your request for organiser rights was not approved at this time.',
      NEW.id,
      'organizer_request'
    );
  end if;

  return NEW;
end;
$$;

create trigger trg_organizer_request_decided
  after update on public.organizer_requests
  for each row execute function public.handle_organizer_request_decision();
