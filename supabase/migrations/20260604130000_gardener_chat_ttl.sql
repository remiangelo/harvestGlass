-- Ephemeral Gardener chat: every message is deleted 24h after it was sent.
--
-- The iOS client purges + filters expired rows whenever the chat is opened
-- (GardenerService.getChatHistory). This hourly cron is the backstop so messages
-- of users who never reopen the chat are still removed.
--
-- Requires the pg_cron extension (Dashboard → Database → Extensions → enable pg_cron).

create extension if not exists pg_cron;

-- Recreate the schedule idempotently.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'purge-gardener-chat-history') then
    perform cron.unschedule('purge-gardener-chat-history');
  end if;
end $$;

select cron.schedule(
  'purge-gardener-chat-history',
  '0 * * * *',  -- top of every hour
  $cron$ delete from public.gardener_chat_history where created_at < now() - interval '24 hours' $cron$
);
