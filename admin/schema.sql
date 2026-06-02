-- Harvest moderation schema additions.
-- Run once in the Supabase SQL editor (Dashboard → SQL Editor → New query → Run).
-- Safe to re-run: every statement is idempotent.

-- 1) Ban flag on user profiles.
--    Banned users are ejected on next app launch (AuthViewModel.loadProfile) and
--    never appear in the discover feed (SwipeService.getDiscoverProfiles).
alter table public.users
  add column if not exists is_banned boolean not null default false;

-- 2) Review-workflow columns on user_reports.
--    user_reports holds both manual reports and the auto-filed report that every
--    block now creates (MatchService.blockUser).
alter table public.user_reports
  add column if not exists status       text not null default 'pending',  -- 'pending' | 'reviewed'
  add column if not exists action_taken text,                             -- 'dismissed' | 'content_removed' | 'banned'
  add column if not exists reviewed_at  timestamptz,
  add column if not exists reviewed_by  text,
  add column if not exists created_at   timestamptz not null default now();

create index if not exists user_reports_status_idx on public.user_reports (status);

-- 3) Convenience view the admin panel reads from: each report joined with the
--    reported user's current profile content and the reporter's name.
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
  reported.nickname  as reported_nickname,
  reported.bio       as reported_bio,
  reported.photos    as reported_photos,
  reported.is_banned as reported_is_banned,
  reporter.nickname  as reporter_nickname
from public.user_reports r
left join public.users reported on reported.id = r.reported_id
left join public.users reporter on reporter.id = r.reporter_id;
