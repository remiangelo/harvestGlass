-- Values graph backfill seed: give every account a populated values radar.
--
-- Run once in the Supabase SQL editor. It is idempotent (safe to re-run) and is a
-- manual seed, NOT a migration — do not add it to the migrations folder.
--
-- The profile "graph" (the values radar) is derived entirely from a user's rows in
-- `user_question_answers` — each answered option maps to one axis
-- (emotional_intelligence / stability / integrity / connection / growth), and NEED vs
-- BRING questions feed the two sides of the chart. With no answers the radar is empty.
--
-- This fills in a full questionnaire (all questions in the `questions` table) for every
-- user who currently has ZERO answers, so empty/test accounts get a graph. It does NOT
-- touch users who already answered anything, so real questionnaire data is never
-- overwritten. Each user gets a deterministic-but-varied set of picks (seeded off the
-- user id) so no two radars look identical.

do $$
declare
  v_seeded int;
  v_users  int;
begin
  with seeded as (
    insert into public.user_question_answers (user_id, question_id, option_id, answered_at)
    select user_id, question_id, option_id, now()
    from (
      -- One option per (user, question): pick the option whose hash sorts first for
      -- this specific user+option pair. Deterministic, re-runnable, and varies per user.
      select distinct on (u.id, q.id)
             u.id  as user_id,
             q.id  as question_id,
             o.id  as option_id
      from public.users u
      cross join public.questions q
      join public.question_options o on o.question_id = q.id
      where not exists (
        select 1 from public.user_question_answers a where a.user_id = u.id
      )
      order by u.id, q.id, md5(u.id::text || o.id)
    ) picks
    on conflict (user_id, question_id) do nothing
    returning user_id
  )
  select count(*), count(distinct user_id) into v_seeded, v_users from seeded;

  raise notice 'Seeded % answers across % previously-empty accounts.', v_seeded, v_users;
end $$;
