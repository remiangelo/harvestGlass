-- Images per Gardener message, laddered by tier.
--
-- Separate from gardener_screenshots_per_day, which counts *messages*: a
-- message carrying six screenshots is still one review. This column caps how
-- much context one review may carry.

alter table public.subscription_tiers
  add column if not exists gardener_images_per_review int not null default 1;

comment on column public.subscription_tiers.gardener_images_per_review is
  'Max images attachable to one Gardener message. A message is one review however many it carries.';

-- Matched on name as well as tier_key, following 20260811100000: a tier row
-- whose tier_key was never backfilled would otherwise keep the default of 1.
update public.subscription_tiers set gardener_images_per_review = 3
  where lower(name) = 'seed' or tier_key = 'seed';
update public.subscription_tiers set gardener_images_per_review = 6
  where lower(name) in ('green', 'grow') or tier_key = 'green';
update public.subscription_tiers set gardener_images_per_review = 10
  where lower(name) = 'gold' or tier_key = 'gold';
