-- Verification for 20260902120000_profile_row_on_signup.sql. Run this AFTER
-- applying the migration. Reads only, writes nothing. Delete this file when
-- you're done with it.
--
-- Every count below should come back 0, and trigger_installed should be true.

select jsonb_pretty(jsonb_build_object(

  'trigger_installed', (
    select count(*) = 1
    from pg_trigger
    where tgrelid = 'auth.users'::regclass
      and tgname = 'on_auth_user_created'
      and not tgisinternal
  ),

  -- The headline: nobody left who can reach onboarding without a row.
  'auth_accounts_missing_a_profile', (
    select count(*)
    from auth.users a
    where a.email is not null
      and not exists (select 1 from public.users u where u.id = a.id)
  ),

  -- Should be 0: step 2 rewrote every address a live account needed.
  'addresses_still_blocked', (
    select count(*)
    from auth.users a
    join public.users u
      on lower(u.email) = lower(a.email) and u.id <> a.id
    where not exists (select 1 from public.users own where own.id = a.id)
  ),

  -- Should be 0: no unreachable row is still shown in the matching pool.
  'ghost_profiles_still_visible', (
    select count(*)
    from public.users u
    where u.onboarding_completed is true
      and not exists (select 1 from auth.users a where a.id = u.id)
  ),

  -- Context, not a failure: the rows step 2 parked. Expect 3.
  'parked_orphan_rows', (
    select count(*) from public.users where email like 'deleted+%@harvest.invalid'
  ),

  'profiles_total', (select count(*) from public.users),
  'auth_users_total', (select count(*) from auth.users)

)) as verify;
