-- Community rooms v2: room images, quote-replies, mentions, reactions.
-- Applied to production via dashboard/execute_sql (remote history not in sync).

-- 1. Room banner images
alter table communities add column if not exists image_url text;

-- 2. Quote-replies + mentions on messages
-- reply_to_id uses ON DELETE SET NULL (not the default NO ACTION/RESTRICT):
-- the users-row cascade that backs account deletion must be able to remove
-- a user's messages even when another user's surviving reply points at one.
alter table community_messages
  add column if not exists reply_to_id uuid references community_messages(id) on delete set null,
  add column if not exists mentions uuid[] not null default '{}';

create index if not exists idx_community_messages_reply_to
  on community_messages (reply_to_id);

-- 3. Reactions (curated set enforced at the DB)
create table if not exists community_message_reactions (
  message_id   uuid not null references community_messages(id) on delete cascade,
  user_id      uuid not null references users(id) on delete cascade,
  emoji        text not null check (emoji in ('🌱','💚','🌻','😂','👏','🤔')),
  community_id uuid not null references communities(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);

create index if not exists idx_reactions_community
  on community_message_reactions (community_id);

-- community_id is denormalized from the parent message so realtime can
-- filter per-room. A trigger fills it; clients never send it.
create or replace function set_reaction_community()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select community_id into new.community_id
  from community_messages where id = new.message_id;
  if new.community_id is null then
    raise exception 'unknown message %', new.message_id;
  end if;
  return new;
end;
$$;

drop trigger if exists reactions_set_community on community_message_reactions;
create trigger reactions_set_community
  before insert on community_message_reactions
  for each row execute function set_reaction_community();

-- 4. RLS
alter table community_message_reactions enable row level security;

drop policy if exists "reactions_select" on community_message_reactions;
create policy "reactions_select" on community_message_reactions
  for select to authenticated
  using (is_active_member(auth.uid(), community_id));

drop policy if exists "reactions_insert" on community_message_reactions;
create policy "reactions_insert" on community_message_reactions
  for insert to authenticated
  with check (user_id = auth.uid() and is_active_member(auth.uid(), community_id));

drop policy if exists "reactions_delete" on community_message_reactions;
create policy "reactions_delete" on community_message_reactions
  for delete to authenticated
  using (user_id = auth.uid());

-- 5. Realtime: INSERT and DELETE events must reach clients (toggling off
-- a reaction has to sync), so replica identity full is required.
alter table community_message_reactions replica identity full;
alter publication supabase_realtime add table community_message_reactions;

-- 6. Storage bucket for room banners (public read; writes only via admin
-- service key, so no authenticated storage policies are needed).
insert into storage.buckets (id, name, public)
values ('community-images', 'community-images', true)
on conflict (id) do nothing;
