-- Deterministic ordering for the icebreaker picker.
alter table public.community_prompts add column if not exists display_order int;

update public.community_prompts set display_order = v.ord
from (values
  ('Coffee, cocktails, or tacos?', 1),
  ('What song are you playing on repeat right now?', 2),
  ('Beach, mountains, or city weekend?', 3),
  ('Dogs, cats, or both?', 4),
  ('What''s something you''re weirdly good at?', 5),
  ('What''s your ideal Sunday?', 6),
  ('What''s your biggest green flag? 🌱', 7),
  ('What''s your biggest dating deal breaker? 👀', 8),
  ('What''s your favorite kind of date?', 9),
  ('What''s something you could talk about for hours?', 10)
) as v(text, ord)
where community_prompts.text = v.text
  and community_prompts.community_id is null
  and community_prompts.is_active;
