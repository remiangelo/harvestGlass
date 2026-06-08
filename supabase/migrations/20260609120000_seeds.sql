-- Seeds: intentional connection requests that replace swipe→match.
-- A Seed is a one-way request carrying an opening message. On accept it
-- creates a matches row + conversation, reusing all existing chat machinery.

-- Per-tier daily send limit (Phase 5 sets the real numbers; default here so
-- the limit trigger works immediately on existing tiers).
alter table public.subscription_tiers
  add column if not exists daily_seed_limit int not null default 3;

create table if not exists public.seeds (
  id              uuid primary key default gen_random_uuid(),
  sender_id       uuid not null references public.users(id) on delete cascade,
  recipient_id    uuid not null references public.users(id) on delete cascade,
  opening_message text not null,
  status          text not null default 'pending'
                    check (status in ('pending','accepted','declined')),
  conversation_id uuid references public.conversations(id) on delete set null,
  created_at      timestamptz not null default now(),
  responded_at    timestamptz,
  check (sender_id <> recipient_id)
);

-- At most one OPEN (pending) seed per directed pair.
create unique index if not exists seeds_one_pending_per_pair
  on public.seeds (sender_id, recipient_id)
  where status = 'pending';

create index if not exists seeds_recipient_idx on public.seeds (recipient_id, status);
create index if not exists seeds_sender_idx    on public.seeds (sender_id, status);

alter table public.seeds enable row level security;

drop policy if exists seeds_select_own on public.seeds;
create policy seeds_select_own on public.seeds
  for select using (auth.uid() = sender_id or auth.uid() = recipient_id);

drop policy if exists seeds_insert_as_sender on public.seeds;
create policy seeds_insert_as_sender on public.seeds
  for insert with check (auth.uid() = sender_id);

-- Recipient may decline directly; accept goes through accept_seed() RPC.
drop policy if exists seeds_recipient_decline on public.seeds;
create policy seeds_recipient_decline on public.seeds
  for update using (auth.uid() = recipient_id)
  with check (auth.uid() = recipient_id);

-- Enforce the sender's daily limit at insert time.
create or replace function enforce_seed_daily_limit() returns trigger
language plpgsql
security definer
as $$
declare
  v_limit int;
  v_sent_today int;
begin
  select coalesce(t.daily_seed_limit, 3)
    into v_limit
    from public.user_subscriptions us
    join public.subscription_tiers t on t.id = us.tier_id
    where us.user_id = NEW.sender_id and us.status = 'active'
    order by us.started_at desc
    limit 1;

  v_limit := coalesce(v_limit, 3);   -- no active subscription => free tier

  select count(*) into v_sent_today
    from public.seeds
    where sender_id = NEW.sender_id
      and created_at >= date_trunc('day', now());

  if v_sent_today >= v_limit then
    raise exception 'SEED_LIMIT_REACHED: daily limit of % seeds reached', v_limit
      using errcode = 'P0001';
  end if;

  return NEW;
end;
$$;

drop trigger if exists seeds_enforce_limit on public.seeds;
create trigger seeds_enforce_limit
  before insert on public.seeds
  for each row execute function enforce_seed_daily_limit();

-- Push the recipient when a Seed arrives (reuses call_send_push from the
-- push-notification-triggers migration).
create or replace function on_seed_after_insert() returns trigger
language plpgsql
security definer
as $$
declare
  v_sender_nickname text;
  v_enabled boolean;
begin
  select coalesce(notif_matches_enabled, true) into v_enabled
    from public.users where id = NEW.recipient_id;
  if not coalesce(v_enabled, true) then
    return NEW;
  end if;

  select coalesce(nickname, 'Someone') into v_sender_nickname
    from public.users where id = NEW.sender_id;

  perform call_send_push(
    recipient => NEW.recipient_id,
    ntype     => 'seed',
    title     => v_sender_nickname || ' sent you a Seed 🌱',
    body      => left(NEW.opening_message, 80),
    deep_link => 'seeds'
  );
  return NEW;
end;
$$;

drop trigger if exists seeds_after_insert on public.seeds;
create trigger seeds_after_insert
  after insert on public.seeds
  for each row execute function on_seed_after_insert();

-- Accept a Seed: create the match + conversation, plant the opening message,
-- and mark the seed accepted — all atomically. Caller must be the recipient.
create or replace function accept_seed(p_seed_id uuid)
returns uuid           -- conversation id
language plpgsql
security definer
as $$
declare
  v_seed public.seeds%rowtype;
  v_match_id uuid;
  v_convo_id uuid;
begin
  select * into v_seed from public.seeds where id = p_seed_id for update;
  if not found then
    raise exception 'SEED_NOT_FOUND';
  end if;
  if v_seed.recipient_id <> auth.uid() then
    raise exception 'NOT_AUTHORIZED';
  end if;
  if v_seed.status <> 'pending' then
    raise exception 'SEED_NOT_PENDING';
  end if;

  insert into public.matches (user1_id, user2_id, is_active, matched_at)
    values (v_seed.sender_id, v_seed.recipient_id, true, now())
    returning id into v_match_id;

  insert into public.conversations (match_id, user1_id, user2_id, created_at, last_message_at, last_message_preview)
    values (v_match_id, v_seed.sender_id, v_seed.recipient_id, now(), now(), left(v_seed.opening_message, 100))
    returning id into v_convo_id;

  insert into public.messages (conversation_id, sender_id, content, message_type, created_at)
    values (v_convo_id, v_seed.sender_id, v_seed.opening_message, 'text', now());

  update public.seeds
    set status = 'accepted', conversation_id = v_convo_id, responded_at = now()
    where id = p_seed_id;

  return v_convo_id;
end;
$$;

grant execute on function accept_seed(uuid) to authenticated;

-- Make sure account deletion also clears seeds (defensive; FK cascade covers it).
-- Handled by on delete cascade above.
