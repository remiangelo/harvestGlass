-- 1. user_devices table

create table user_devices (
  user_id     uuid not null references users(id) on delete cascade,
  apns_token  text not null,
  platform    text not null default 'ios' check (platform in ('ios')),
  created_at  timestamptz default now(),
  updated_at  timestamptz default now(),
  primary key (user_id, apns_token)
);

create index user_devices_user_id_idx on user_devices(user_id);

alter table user_devices enable row level security;

create policy "devices_self_rw" on user_devices
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 2. users notification preference columns

alter table users
  add column notif_messages_enabled        boolean default true,
  add column notif_matches_enabled         boolean default true,
  add column notif_likes_enabled           boolean default true,
  add column notif_gardener_local_enabled  boolean default true,
  add column notif_gardener_local_hour     int default 9 check (notif_gardener_local_hour between 0 and 23);

-- 3. pg_net extension (required for triggers to call the Edge Function in Task 3)

create extension if not exists pg_net;
