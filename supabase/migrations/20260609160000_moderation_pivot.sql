-- Moderation pivot: report targets, community-message contact-info guard,
-- and an updated moderation_queue view that surfaces message targets.

alter table public.user_reports
  add column if not exists target_type text not null default 'profile'
      check (target_type in ('profile','community_message','seed_message')),
  add column if not exists target_id   uuid;   -- message id when applicable

-- ── Contact-info detection (community chat only) ────────────────────────────
-- Blocks phone numbers and Snap/Instagram handle-drops to keep contact sharing
-- inside private Seed conversations. Conservative patterns; tune as needed.
create or replace function detect_contact_info(p_text text)
returns boolean language plpgsql immutable as $$
declare t text := lower(coalesce(p_text,''));
begin
  -- 7+ digit run (with common separators) => likely a phone number
  if t ~ '(\d[\s().+-]?){7,}' then return true; end if;
  -- social handle solicitation
  if t ~* '(snap(chat)?|insta(gram)?|\+?my\s+(snap|ig|insta)|add\s+me\s+on)' then return true; end if;
  -- @handle of 3+ chars
  if t ~ '@[a-z0-9_.]{3,}' then return true; end if;
  return false;
end;
$$;

create or replace function guard_community_contact_info() returns trigger
language plpgsql as $$
begin
  if detect_contact_info(NEW.content) then
    raise exception 'CONTACT_INFO_BLOCKED' using errcode = 'P0001';
  end if;
  return NEW;
end;
$$;

drop trigger if exists community_messages_contact_guard on public.community_messages;
create trigger community_messages_contact_guard
  before insert on public.community_messages
  for each row execute function guard_community_contact_info();

-- ── moderation_queue view (replaces the one in admin/schema.sql) ────────────
create or replace view public.moderation_queue as
select
  r.id,
  r.reporter_id,
  r.reported_id,
  r.reason,
  r.description,
  r.status,
  r.action_taken,
  r.created_at,
  r.target_type,
  r.target_id,
  reported.nickname  as reported_nickname,
  reported.bio       as reported_bio,
  reported.photos    as reported_photos,
  reported.is_banned as reported_is_banned,
  reporter.nickname  as reporter_nickname,
  cm.content         as target_message_content,
  cm.community_id    as target_community_id,
  comm.name          as target_community_name
from public.user_reports r
left join public.users reported on reported.id = r.reported_id
left join public.users reporter on reporter.id = r.reporter_id
left join public.community_messages cm
       on r.target_type = 'community_message' and cm.id = r.target_id
left join public.communities comm on comm.id = cm.community_id;
