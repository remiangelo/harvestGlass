-- Replace the global community icebreakers with a lighter, more casual set.
-- Old prompts are deactivated (not deleted) so any analytics/history stay intact.

update public.community_prompts
   set is_active = false
 where community_id is null
   and is_active;

insert into public.community_prompts (community_id, text) values
  (null,'Coffee, cocktails, or tacos?'),
  (null,'What song are you playing on repeat right now?'),
  (null,'Beach, mountains, or city weekend?'),
  (null,'Dogs, cats, or both?'),
  (null,'What''s something you''re weirdly good at?'),
  (null,'What''s your ideal Sunday?'),
  (null,'What''s your biggest green flag? 🌱'),
  (null,'What''s your biggest dating deal breaker? 👀'),
  (null,'What''s your favorite kind of date?'),
  (null,'What''s something you could talk about for hours?');
