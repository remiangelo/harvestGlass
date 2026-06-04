-- App Review demo seed: a ready-made match + conversation for the reviewer.
--
-- Run once in the Supabase SQL editor. It is idempotent (safe to re-run) and is a
-- manual seed, NOT a migration — do not add it to the migrations folder.
--
-- It matches the Gold test account with an existing second account so the reviewer
-- can open the Chat tab and immediately see a conversation. The last message is sent
-- TO the Gold account and contains a mild flagged word ("idiot") so the reviewer can
-- see mindful-messaging blur-on-receive and the in-chat Report/Block tools.
--
-- ▶ Fill in the second account's email (your Seed/free test login) below.

do $$
declare
  v_gold    uuid;
  v_partner uuid;
  v_match   uuid;
  v_convo   uuid;
begin
  select id into v_gold    from public.users where lower(email) = lower('testGold@harvest.com');
  select id into v_partner from public.users where lower(email) = lower('REPLACE_WITH_SEED_ACCOUNT_EMAIL');

  if v_gold is null or v_partner is null then
    raise exception 'Could not resolve both users (gold=%, partner=%). Check the emails.', v_gold, v_partner;
  end if;

  -- Mutual likes so the pairing looks organic.
  insert into public.swipes (swiper_id, swiped_id, action)
  values (v_gold, v_partner, 'like'),
         (v_partner, v_gold, 'like')
  on conflict do nothing;

  -- Reuse an existing active match for the pair, else create one.
  select id into v_match
    from public.matches
   where is_active = true
     and ((user1_id = v_gold and user2_id = v_partner)
       or (user1_id = v_partner and user2_id = v_gold))
   limit 1;

  if v_match is null then
    insert into public.matches (user1_id, user2_id, is_active, matched_at)
    values (v_gold, v_partner, true, now())
    returning id into v_match;
  end if;

  -- Reuse an existing conversation for the match, else create one.
  select id into v_convo from public.conversations where match_id = v_match limit 1;

  if v_convo is null then
    insert into public.conversations (match_id, user1_id, user2_id, created_at)
    values (v_match, v_gold, v_partner, now())
    returning id into v_convo;
  end if;

  -- Seed messages only if the conversation is empty.
  if not exists (select 1 from public.messages where conversation_id = v_convo) then
    insert into public.messages (conversation_id, sender_id, content, message_type, created_at, is_read)
    values
      (v_convo, v_partner, 'Hey! Loved your values chart — Connection really stood out for me.', 'text', now() - interval '20 minutes', true),
      (v_convo, v_gold,    'Thank you! Yours too. What are you hoping to find on Harvest?',        'text', now() - interval '18 minutes', true),
      (v_convo, v_partner, 'Something real. Also you''re an idiot for not messaging me sooner 😄',  'text', now() - interval '2 minutes',  false);

    update public.conversations
       set last_message_at      = now() - interval '2 minutes',
           last_message_preview = 'Something real. Also you''re an idiot for not messaging me sooner 😄'
     where id = v_convo;
  end if;

  raise notice 'Seeded match % and conversation % between gold % and partner %', v_match, v_convo, v_gold, v_partner;
end $$;
