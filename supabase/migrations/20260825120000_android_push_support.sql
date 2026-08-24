-- Android push support.
--
-- `user_devices` was written when iOS was the only client: `platform` is
-- CHECK-constrained to 'ios' alone, so an Android registration is rejected
-- outright rather than merely ignored.
--
-- This is deliberately additive. The `apns_token` column keeps its name even
-- though it now also carries FCM registration tokens: renaming it would break
-- the shipped iOS client and the send-push function in the same deploy, and a
-- column name is a cheaper thing to live with than a coordinated release.

-- 1. Allow Android rows.

alter table user_devices
  drop constraint if exists user_devices_platform_check;

alter table user_devices
  add constraint user_devices_platform_check
  check (platform in ('ios', 'android'));

comment on column user_devices.apns_token is
  'Device push token. APNs token for platform=ios, FCM registration token for platform=android. Named for its original iOS-only use.';

comment on column user_devices.platform is
  'ios | android. Determines which push service send-push dispatches through.';

-- 2. send-push selects on platform, so index the pair it filters by.

create index if not exists user_devices_user_platform_idx
  on user_devices (user_id, platform);
