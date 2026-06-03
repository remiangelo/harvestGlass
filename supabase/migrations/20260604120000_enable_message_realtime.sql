-- Enable Supabase Realtime for live chat.
--
-- Without the `messages` table in the `supabase_realtime` publication, the iOS
-- client's postgres_changes subscription (ChatService.subscribeToMessages) never
-- fires, so new messages only appear after leaving and re-entering a chat (which
-- re-fetches via getMessages). The client code is correct; the table just has to
-- be published.
--
-- Equivalent dashboard action: Database → Replication → supabase_realtime → enable `messages`.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;

-- Carry full row data on changes (needed for filtered/updated realtime events).
alter table public.messages replica identity full;
