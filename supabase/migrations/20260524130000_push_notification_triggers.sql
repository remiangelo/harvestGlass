-- This migration creates three Postgres triggers that call the send-push
-- Edge Function via pg_net when messages, matches, or likes are inserted.
--
-- BEFORE applying this migration, two secrets must exist in Supabase Vault:
--   - send_push_url            : full URL to the Edge Function, e.g.
--                                https://<project>.supabase.co/functions/v1/send-push
--   - send_push_service_role   : service_role JWT for the project
--
-- Create them via SQL (one-time, in the dashboard SQL editor):
--   select vault.create_secret('https://<project>.supabase.co/functions/v1/send-push', 'send_push_url');
--   select vault.create_secret('<service_role_jwt>', 'send_push_service_role');

create or replace function call_send_push(
  recipient uuid,
  ntype text,
  title text,
  body text,
  deep_link text,
  thread_id text default null,
  badge_count int default null
) returns void
language plpgsql
security definer
as $$
declare
  v_url text;
  v_jwt text;
  v_payload jsonb;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'send_push_url';
  select decrypted_secret into v_jwt
    from vault.decrypted_secrets where name = 'send_push_service_role';

  if v_url is null or v_jwt is null then
    raise warning 'call_send_push: vault secrets missing (send_push_url / send_push_service_role)';
    return;
  end if;

  v_payload := jsonb_build_object(
    'recipient_user_id', recipient,
    'type', ntype,
    'payload', jsonb_build_object(
      'title', title,
      'body', body,
      'deepLink', deep_link,
      'threadId', thread_id,
      'badgeCount', badge_count
    )
  );

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_jwt
    ),
    body := v_payload
  );
end;
$$;

-- 1. messages_after_insert trigger

create or replace function on_messages_after_insert() returns trigger
language plpgsql
security definer
as $$
declare
  v_recipient uuid;
  v_sender_nickname text;
  v_body text;
  v_messages_enabled boolean;
begin
  -- Determine recipient = the conversation participant other than the sender
  select case
           when c.user1_id = NEW.sender_id then c.user2_id
           else c.user1_id
         end
    into v_recipient
    from conversations c
    where c.id = NEW.conversation_id;

  if v_recipient is null or v_recipient = NEW.sender_id then
    return NEW;
  end if;

  -- Honor recipient preference
  select coalesce(notif_messages_enabled, true) into v_messages_enabled
    from users where id = v_recipient;
  if not v_messages_enabled then
    return NEW;
  end if;

  select coalesce(nickname, 'Someone') into v_sender_nickname
    from users where id = NEW.sender_id;

  if NEW.message_type = 'image' or (NEW.content is null or NEW.content = '') then
    v_body := 'Sent you a photo';
  else
    v_body := left(NEW.content, 80);
  end if;

  perform call_send_push(
    recipient   => v_recipient,
    ntype       => 'message',
    title       => v_sender_nickname,
    body        => v_body,
    deep_link   => 'chat:' || NEW.conversation_id,
    thread_id   => NEW.conversation_id::text,
    badge_count => null    -- v1: omit badge; see spec §4.1 fallback
  );

  return NEW;
end;
$$;

drop trigger if exists messages_after_insert on messages;
create trigger messages_after_insert
  after insert on messages
  for each row
  execute function on_messages_after_insert();

-- 2. matches_after_insert trigger

create or replace function on_matches_after_insert() returns trigger
language plpgsql
security definer
as $$
declare
  v_user1_nickname text;
  v_user2_nickname text;
  v_user1_enabled boolean;
  v_user2_enabled boolean;
begin
  select coalesce(nickname, 'Someone') into v_user1_nickname from users where id = NEW.user1_id;
  select coalesce(nickname, 'Someone') into v_user2_nickname from users where id = NEW.user2_id;

  select coalesce(notif_matches_enabled, true) into v_user1_enabled from users where id = NEW.user1_id;
  select coalesce(notif_matches_enabled, true) into v_user2_enabled from users where id = NEW.user2_id;

  if v_user1_enabled then
    perform call_send_push(
      recipient => NEW.user1_id,
      ntype     => 'match',
      title     => 'New match',
      body      => 'You matched with ' || v_user2_nickname || ' 🌱',
      deep_link => 'match:' || NEW.id::text
    );
  end if;

  if v_user2_enabled then
    perform call_send_push(
      recipient => NEW.user2_id,
      ntype     => 'match',
      title     => 'New match',
      body      => 'You matched with ' || v_user1_nickname || ' 🌱',
      deep_link => 'match:' || NEW.id::text
    );
  end if;

  return NEW;
end;
$$;

drop trigger if exists matches_after_insert on matches;
create trigger matches_after_insert
  after insert on matches
  for each row
  execute function on_matches_after_insert();

-- 3. swipes_after_insert trigger (inbound-like push for Gold tier)

create or replace function on_swipes_after_insert() returns trigger
language plpgsql
security definer
as $$
declare
  v_can_see_likes boolean := false;
  v_likes_enabled boolean;
begin
  if NEW.action not in ('like', 'super_like') then
    return NEW;
  end if;

  select coalesce(notif_likes_enabled, true) into v_likes_enabled
    from users where id = NEW.swiped_id;
  if not v_likes_enabled then
    return NEW;
  end if;

  -- Gate on Gold tier: only users whose active subscription tier sets
  -- can_see_likes = true should receive the inbound-like push.
  select coalesce(t.can_see_likes, false)
    into v_can_see_likes
    from user_subscriptions us
    join subscription_tiers t on t.id = us.tier_id
    where us.user_id = NEW.swiped_id
      and us.status = 'active'
    order by us.started_at desc
    limit 1;

  if not v_can_see_likes then
    return NEW;
  end if;

  perform call_send_push(
    recipient => NEW.swiped_id,
    ntype     => 'like',
    title     => 'Harvest',
    body      => 'Someone likes you',
    deep_link => 'likes',
    thread_id => 'likes:' || NEW.swiped_id::text
  );

  return NEW;
end;
$$;

drop trigger if exists swipes_after_insert on swipes;
create trigger swipes_after_insert
  after insert on swipes
  for each row
  execute function on_swipes_after_insert();
