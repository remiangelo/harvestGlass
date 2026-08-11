-- Re-point the subscription tiers at the post-pivot app: Seeds · The Field ·
-- the Gardener · Soil. Prices are unchanged ($0 / $19.99 / $24.99) and the
-- three tier rows keep their ids, so live subscriptions are untouched.
--
-- What goes away is the swipe era. None of it is read by the app any more:
--   matches_per_week / max_distance_miles  gated a swipe deck that no longer exists
--   has_basic/advanced/full_filters        never read — the roster and Discover
--                                          filters branch on tier *name* instead
--   has_values_matching                    matching is gone
--   can_see_likes                          gated the legacy "Likes You" list
--
-- Apply through the dashboard (this project's history is not in sync with
-- supabase/migrations/). The DROP at the end will fail loudly if a view,
-- policy or function still depends on one of these columns — that is
-- deliberate, do not add CASCADE without checking what it would take with it.

begin;

-- 1. New gates, added before anything is dropped.

alter table public.subscription_tiers
  add column if not exists field_filter_level           text    not null default 'none',
  add column if not exists gardener_screenshots_per_day int     not null default 1,
  add column if not exists has_deep_soil_insights       boolean not null default false,
  add column if not exists has_growth_features          boolean not null default false;

comment on column public.subscription_tiers.field_filter_level is
  'Room member roster + profile filters: none | advanced | full';
comment on column public.subscription_tiers.gardener_screenshots_per_day is
  'Screenshot reviews per day. Separate from gardener_character_limit — a review no longer spends the chat budget.';

alter table public.subscription_tiers
  drop constraint if exists subscription_tiers_field_filter_level_check;

alter table public.subscription_tiers
  add constraint subscription_tiers_field_filter_level_check
  check (field_filter_level in ('none', 'advanced', 'full'));

-- 2. Screenshot reviews get their own daily counter, reset alongside the
--    existing gardener_* daily fields.

alter table public.user_usage
  add column if not exists gardener_screenshots_today int not null default 0;

-- 3. Tier values. Prices are deliberately not touched.

-- 🌱 Seed — free
update public.subscription_tiers set
  daily_seed_limit             = 3,
  gardener_character_limit     = 2000,
  gardener_screenshots_per_day = 1,
  field_filter_level           = 'none',
  has_deep_soil_insights       = false,
  has_growth_features          = false
where lower(name) = 'seed' or tier_key = 'seed';

-- 🌿 Green (marketed as "Grow")
update public.subscription_tiers set
  daily_seed_limit             = 5,
  gardener_character_limit     = 10000,
  gardener_screenshots_per_day = 5,
  field_filter_level           = 'advanced',
  has_deep_soil_insights       = true,
  has_growth_features          = false
where lower(name) in ('green', 'grow') or tier_key = 'green';

-- 🌳 Gold
update public.subscription_tiers set
  daily_seed_limit             = 25,
  gardener_character_limit     = 25000,
  gardener_screenshots_per_day = 20,
  field_filter_level           = 'full',
  has_deep_soil_insights       = true,
  has_growth_features          = true
where lower(name) = 'gold' or tier_key = 'gold';

-- 4. Swipe-era columns, dropped last so a failure above leaves them intact.
--    Clients older than this change decode every tier field with
--    decodeIfPresent, so they keep working against the narrower row.

alter table public.subscription_tiers
  drop column if exists matches_per_week,
  drop column if exists max_distance_miles,
  drop column if exists can_see_likes,
  drop column if exists has_values_matching,
  drop column if exists has_basic_filters,
  drop column if exists has_advanced_filters,
  drop column if exists has_full_filters;

commit;

-- Verify:
--   select name, tier_key, price_monthly, daily_seed_limit,
--          gardener_character_limit, gardener_screenshots_per_day,
--          field_filter_level, has_deep_soil_insights, has_growth_features
--     from public.subscription_tiers order by sort_order;
