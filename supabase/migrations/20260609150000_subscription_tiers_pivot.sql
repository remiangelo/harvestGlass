-- Pivot subscription tiers: daily Seed limits + pricing + gardener access.
alter table public.subscription_tiers
  add column if not exists price_cents      int   not null default 0,
  add column if not exists gardener_access  text  not null default 'limited',  -- limited|more|full
  add column if not exists tier_key         text;                              -- stable key: seed|green|gold

-- daily_seed_limit already added in 20260609120000_seeds.sql.

-- Map existing rows to the three pivot tiers. EDIT the WHERE clauses to match
-- the real id/name values found in Step 1. Example assumes rows are named
-- 'free'/'green'/'gold' (case-insensitive); adjust as needed.
update public.subscription_tiers
  set tier_key='seed',  daily_seed_limit=3,  price_cents=0,    gardener_access='limited', can_see_likes=false
  where lower(name) in ('free','seed','basic') or tier_key='seed';

update public.subscription_tiers
  set tier_key='green', daily_seed_limit=5,  price_cents=1999, gardener_access='more',    can_see_likes=true
  where lower(name) in ('green','plus') or tier_key='green';

update public.subscription_tiers
  set tier_key='gold',  daily_seed_limit=25, price_cents=2499, gardener_access='full',    can_see_likes=true
  where lower(name) in ('gold','premium') or tier_key='gold';

-- If a fresh project has NO tiers, create them (no-op when rows already exist):
insert into public.subscription_tiers (name, tier_key, daily_seed_limit, price_cents, gardener_access, can_see_likes)
select * from (values
  ('Seed',  'seed',  3,  0,    'limited', false),
  ('Green', 'green', 5,  1999, 'more',    true),
  ('Gold',  'gold',  25, 2499, 'full',    true)
) as v(name, tier_key, daily_seed_limit, price_cents, gardener_access, can_see_likes)
where not exists (select 1 from public.subscription_tiers);
