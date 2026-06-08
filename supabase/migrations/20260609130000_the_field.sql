-- The Field: community spaces + membership + room chat + access rules.

-- Relationship status lives here because the access function depends on it.
alter table public.users
  add column if not exists relationship_status text;   -- single|dating|in_relationship|engaged|married

create table if not exists public.communities (
  id            uuid primary key default gen_random_uuid(),
  slug          text unique not null,
  name          text not null,
  description   text,
  kind          text not null default 'everyone'
                  check (kind in ('everyone','seeking_connection','relationship_stage','peer')),
  is_active     boolean not null default true,
  member_count  int not null default 0,
  display_order int not null default 0
);

create table if not exists public.community_members (
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id      uuid not null references public.users(id) on delete cascade,
  role         text not null default 'member' check (role in ('member','moderator')),
  status       text not null default 'active' check (status in ('active','banned','left')),
  joined_at    timestamptz not null default now(),
  primary key (community_id, user_id)
);

create table if not exists public.community_messages (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  sender_id    uuid not null references public.users(id) on delete cascade,
  content      text not null,
  is_removed   boolean not null default false,
  removed_by   uuid,
  removed_at   timestamptz,
  created_at   timestamptz not null default now()
);
create index if not exists community_messages_room_idx
  on public.community_messages (community_id, created_at);

create table if not exists public.community_prompts (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid references public.communities(id) on delete cascade,  -- null = all rooms
  text         text not null,
  is_active    boolean not null default true
);

-- ── Access rules ──────────────────────────────────────────────────────────
-- Returns the communities a user MAY join, from gender + interested_in + status.
-- NOTE: confirm the exact gender / interested_in tokens stored by
-- GenderStepView / InterestedInStepView; normalization below covers common forms.
create or replace function available_communities(p_user uuid)
returns setof public.communities
language plpgsql
stable
security definer
as $$
declare
  v_gender   text;
  v_int      text[];
  v_status   text;
  is_woman   boolean;
  is_man     boolean;
  is_nb      boolean;
  wants_men   boolean;
  wants_women boolean;
  v_eligible boolean;   -- eligible for Seeking Connection rooms
begin
  select lower(coalesce(gender,'')),
         coalesce(interested_in, array[]::text[]),
         lower(coalesce(relationship_status,''))
    into v_gender, v_int, v_status
    from public.users where id = p_user;

  -- Normalize interested_in tokens to lowercase.
  v_int := array(select lower(x) from unnest(v_int) as x);

  is_woman := v_gender = any (array['woman','women','female','f']);
  is_man   := v_gender = any (array['man','men','male','m']);
  is_nb    := v_gender = any (array['non-binary','nonbinary','nb','enby','non binary']);

  wants_women := v_int && array['woman','women','female','f'];
  wants_men   := v_int && array['man','men','male','m'];

  -- Seeking Connection rooms require an active dating season.
  v_eligible := v_status in ('single','dating');

  return query
  select c.* from public.communities c
  where c.is_active and (
    c.kind = 'everyone'
    or (c.kind = 'seeking_connection' and v_eligible and (
          (c.slug = 'women-men'       and ((is_woman and wants_men) or (is_man and wants_women) or is_nb))
       or (c.slug = 'women-women'      and ((is_woman and wants_women) or is_nb))
       or (c.slug = 'men-men'          and ((is_man and wants_men) or is_nb))
       or (c.slug = 'open-connections')   -- catch-all for all eligible users
    ))
  )
  order by c.display_order;
end;
$$;
grant execute on function available_communities(uuid) to authenticated;

create or replace function can_join_community(p_user uuid, p_community uuid)
returns boolean language sql stable security definer as $$
  select exists (select 1 from available_communities(p_user) c where c.id = p_community);
$$;
grant execute on function can_join_community(uuid, uuid) to authenticated;

create or replace function is_active_member(p_user uuid, p_community uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.community_members
    where community_id = p_community and user_id = p_user and status = 'active'
  );
$$;
grant execute on function is_active_member(uuid, uuid) to authenticated;

-- ── RLS ──────────────────────────────────────────────────────────────────
alter table public.communities       enable row level security;
alter table public.community_members  enable row level security;
alter table public.community_messages enable row level security;
alter table public.community_prompts   enable row level security;

drop policy if exists communities_read on public.communities;
create policy communities_read on public.communities
  for select using (true);   -- directory is readable; app shows joinable vs available

drop policy if exists prompts_read on public.community_prompts;
create policy prompts_read on public.community_prompts
  for select using (true);

drop policy if exists members_read_own on public.community_members;
create policy members_read_own on public.community_members
  for select using (auth.uid() = user_id or is_active_member(auth.uid(), community_id));

drop policy if exists members_join on public.community_members;
create policy members_join on public.community_members
  for insert with check (auth.uid() = user_id and can_join_community(auth.uid(), community_id));

drop policy if exists members_update_own on public.community_members;
create policy members_update_own on public.community_members
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists messages_read on public.community_messages;
create policy messages_read on public.community_messages
  for select using (is_active_member(auth.uid(), community_id));

drop policy if exists messages_post on public.community_messages;
create policy messages_post on public.community_messages
  for insert with check (auth.uid() = sender_id and is_active_member(auth.uid(), community_id));

-- ── member_count maintenance ───────────────────────────────────────────────
create or replace function refresh_community_count() returns trigger
language plpgsql security definer as $$
begin
  update public.communities c
    set member_count = (
      select count(*) from public.community_members m
      where m.community_id = c.id and m.status = 'active'
    )
  where c.id = coalesce(NEW.community_id, OLD.community_id);
  return null;
end;
$$;
drop trigger if exists community_members_count on public.community_members;
create trigger community_members_count
  after insert or update or delete on public.community_members
  for each row execute function refresh_community_count();

-- ── Realtime for room chat ──────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='community_messages'
  ) then
    alter publication supabase_realtime add table public.community_messages;
  end if;
end $$;
alter table public.community_messages replica identity full;

-- ── Seed the MVP rooms ──────────────────────────────────────────────────────
insert into public.communities (slug, name, description, kind, display_order) values
  ('everyones-field','Everyone''s Field','General conversations about relationships, values, and intentional connection.','everyone',0),
  ('women-men','Women + Men Connections','For women interested in meeting men and men interested in meeting women.','seeking_connection',1),
  ('women-women','Women + Women Connections','For women interested in meeting women.','seeking_connection',2),
  ('men-men','Men + Men Connections','For men interested in meeting men.','seeking_connection',3),
  ('open-connections','Open Connections','For anyone open to broader discovery and non-binary connections.','seeking_connection',4)
on conflict (slug) do nothing;

-- ── Seed icebreaker prompts (apply to all rooms) ────────────────────────────
insert into public.community_prompts (community_id, text) values
  (null,'What value are you working on strengthening in yourself right now?'),
  (null,'What value do you most hope a partner brings?'),
  (null,'What does consistency look like to you?'),
  (null,'What is one way you feel most loved?'),
  (null,'What relationship pattern are you trying to grow beyond?'),
  (null,'What does emotional safety mean to you?'),
  (null,'What helps you feel respected in a relationship?'),
  (null,'What does intentional connection look like to you right now?')
on conflict do nothing;
