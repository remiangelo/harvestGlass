-- Images per Gardener message, laddered by tier.
--
-- Separate from gardener_screenshots_per_day, which counts *messages*: a
-- message carrying six screenshots is still one review. This column caps how
-- much context one review may carry.

alter table public.subscription_tiers
  add column if not exists gardener_images_per_review int not null default 1;

comment on column public.subscription_tiers.gardener_images_per_review is
  'Max images attachable to one Gardener message. A message is one review however many it carries.';

update public.subscription_tiers set gardener_images_per_review = 3  where tier_key = 'seed';
update public.subscription_tiers set gardener_images_per_review = 6  where tier_key = 'green';
update public.subscription_tiers set gardener_images_per_review = 10 where tier_key = 'gold';
