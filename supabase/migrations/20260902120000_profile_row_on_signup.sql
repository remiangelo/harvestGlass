-- Create the profile row from the database, not from the client.
--
-- `public.users.email` is NOT NULL and UNIQUE with no default, and nothing has
-- ever created the row except the apps themselves, immediately after sign-up.
-- Every client path that can miss leaves an authenticated account with no
-- profile row:
--
--   * Android — supabase-kt's `signUpWith` returns null whenever the sign-up
--     response carries an access_token (i.e. whenever email confirmation is
--     off, which is this project's configuration). AuthViewModel.register
--     guards on `if (userId != null)`, so `createProfile` is skipped outright.
--   * iOS — any throw from `createProfile` is caught and shown, but the
--     Supabase session has already been persisted to the keychain, so the next
--     launch signs the user straight in. A dropped connection is enough, and so
--     is 23505 from `users_email_key` when a stale row still holds the address.
--
-- Either way the account reaches onboarding with no row. `completeOnboarding`
-- then falls back to `upsertProfile`, whose payload has no `email` — and
-- Postgres validates NOT NULL on the proposed tuple *before* it resolves
-- ON CONFLICT, so that fallback raises 23502 even when a row does exist. The
-- user is told "Failed to save profile" at the last step of onboarding and has
-- no way forward.
--
-- 12 of 49 accounts were in this state when this migration was written.
--
-- Creating the row from a trigger fixes it for every client at once, and the
-- repair below releases the already-stranded accounts without an app update:
-- once the row exists, the `updateProfile` path succeeds and the fallback is
-- never reached.

-- 1. Create the profile row alongside the auth account.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- The apps only ever sign users up with an email, but a null one would
  -- violate users.email NOT NULL and take the whole auth insert down with it.
  -- Skipping is the lesser failure: the account still exists, and this is the
  -- same position every account was in before this trigger.
  if new.email is null then
    return new;
  end if;

  -- Untargeted ON CONFLICT on purpose: it covers users_email_key as well as
  -- the primary key. A targeted `on conflict (id)` would raise 23505 whenever
  -- a stale row still held the address — inside an AFTER INSERT trigger on
  -- auth.users, which aborts the insert. That would turn a missing profile row
  -- into a sign-up that cannot complete at all.
  insert into public.users (id, email, nickname, bio, created_at, updated_at)
  values (
    new.id,
    new.email,
    -- Mirrors ProfileService.defaultNickname on both clients.
    coalesce(nullif(split_part(new.email, '@', 1), ''), 'User'),
    'I''m new here!',
    now(),
    now()
  )
  on conflict do nothing;

  return new;
end;
$$;

comment on function public.handle_new_user is
  'Creates the public.users row for a new auth account. The clients also upsert one at sign-up; both are idempotent via ON CONFLICT DO NOTHING.';

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2. Release addresses held by profile rows whose auth account is gone.
--
-- Three accounts were deleted in a way that took the auth user but left the
-- profile row behind, and each of those people then registered again. The old
-- row still holds their address, so `users_email_key` blocks any new row for
-- the new account — which is how they ended up stranded at onboarding.
--
-- Nobody can ever authenticate as these ids again, so the rows are unreachable
-- rather than merely inactive. The addresses observed on 2026-09-02, recorded
-- here because the update overwrites them:
--
--   5e8a7481-f8eb-4107-9fa3-d6841f7ce8d9  xlolprismx@gmail.com
--   50949b6a-cbe0-4a62-a161-32fdcda8f4f9  mixedbyremi@gmail.com
--   f35b5fd2-9e76-4ecc-a39a-bbd96c217eda  remi.beltram@icloud.com
--
-- Rewriting rather than deleting is deliberate: these rows are the anchor for
-- whatever swipes, matches and messages they accumulated, and dropping them
-- would take that with them. `.invalid` is reserved by RFC 2606, so the
-- placeholder can never collide with a real address.

update public.users u
set
  email = 'deleted+' || u.id || '@harvest.invalid',
  updated_at = now()
where not exists (select 1 from auth.users a where a.id = u.id)
  and exists (
    select 1 from auth.users a2 where lower(a2.email) = lower(u.email)
  );

-- 3. Take unreachable profiles out of the matching pool.
--
-- The `Users can view other profiles for matching` policy is
-- `USING (onboarding_completed = true AND id <> auth.uid())`, so an orphaned
-- row with a completed profile is still shown to everyone. Two of the three
-- above were. Swiping on a profile that cannot ever respond is worse than not
-- seeing it, and this is reversible if any of them is ever reattached.

update public.users u
set
  onboarding_completed = false,
  updated_at = now()
where u.onboarding_completed is true
  and not exists (select 1 from auth.users a where a.id = u.id);

-- 4. Give the stranded accounts their profile row.
--
-- `created_at` is taken from the auth account rather than now(), so these read
-- as the accounts they are rather than as sign-ups dated to this migration.
-- The email guard is belt and braces: step 2 should have cleared every
-- collision, and anything still holding an address is something this migration
-- has not accounted for and should be looked at rather than worked around.

insert into public.users (id, email, nickname, bio, created_at, updated_at)
select
  a.id,
  a.email,
  coalesce(nullif(split_part(a.email, '@', 1), ''), 'User'),
  'I''m new here!',
  a.created_at,
  now()
from auth.users a
left join public.users u on u.id = a.id
where u.id is null
  and a.email is not null
  and not exists (
    select 1 from public.users e where lower(e.email) = lower(a.email)
  )
on conflict do nothing;
