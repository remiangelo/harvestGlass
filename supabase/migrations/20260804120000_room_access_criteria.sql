-- Admin-authored room access criteria.
--
-- Rooms gain a `criteria` jsonb describing who may DISCOVER and JOIN them.
-- Existing members are grandfathered: criteria never revoke a membership,
-- they only gate available_communities(), which both discovery and
-- can_join_community() read from.
--
-- Design notes:
--   * An absent key, a null, or an empty array means "no constraint".
--   * All present keys are ANDed.
--   * A NULL profile attribute FAILS a present constraint. This is the
--     opposite of the in-app roster filter, and it is deliberate: the lenient
--     rule would let anyone into every restricted room by leaving fields
--     blank, exactly inverting the feature.
--   * Existing rooms get '{}' and remain visible to precisely who they were
--     visible to before.

create extension if not exists cube;
create extension if not exists earthdistance;

alter table public.communities
  add column if not exists criteria jsonb not null default '{}'::jsonb;

alter table public.users
  add column if not exists latitude  double precision,
  add column if not exists longitude double precision;

-- Backfilled on-device: the app geocodes users who have a location string but
-- no coordinates. Until then they match no location-restricted room.
create index if not exists users_earth_idx
  on public.users using gist (ll_to_earth(latitude, longitude))
  where latitude is not null and longitude is not null;

-- Case-insensitive membership of a scalar in a criteria array.
-- Returns true when the constraint is absent/empty (no constraint),
-- false when the user's value is null but a constraint exists.
create or replace function public.criteria_allows_text(
  p_criteria jsonb, p_key text, p_value text
) returns boolean language sql immutable set search_path = public as $$
  select case
    when p_criteria -> p_key is null
      or jsonb_typeof(p_criteria -> p_key) <> 'array'
      or jsonb_array_length(p_criteria -> p_key) = 0
      then true
    when p_value is null or btrim(p_value) = ''
      then false
    else exists (
      select 1
      from jsonb_array_elements_text(p_criteria -> p_key) as allowed(v)
      where lower(btrim(allowed.v)) = lower(btrim(p_value))
    )
  end;
$$;

-- Inclusive numeric range check against {"min": x, "max": y}; either bound
-- may be absent. Null user value fails whenever any bound is present.
create or replace function public.criteria_allows_number(
  p_criteria jsonb, p_key text, p_value numeric
) returns boolean language sql immutable set search_path = public as $$
  select case
    when p_criteria -> p_key is null
      or jsonb_typeof(p_criteria -> p_key) <> 'object'
      or ((p_criteria -> p_key -> 'min') is null and (p_criteria -> p_key -> 'max') is null)
      then true
    when p_value is null
      then false
    else
      coalesce(p_value >= (p_criteria -> p_key ->> 'min')::numeric, true)
      and
      coalesce(p_value <= (p_criteria -> p_key ->> 'max')::numeric, true)
  end;
$$;

-- Radius check against {"lat":..,"lng":..,"radius_miles":..}.
-- earth_distance returns metres; 1 mile = 1609.344 m.
create or replace function public.criteria_allows_location(
  p_criteria jsonb, p_lat double precision, p_lng double precision
) returns boolean language sql immutable set search_path = public as $$
  select case
    when p_criteria -> 'location' is null
      or (p_criteria -> 'location' ->> 'lat') is null
      or (p_criteria -> 'location' ->> 'lng') is null
      or (p_criteria -> 'location' ->> 'radius_miles') is null
      then true
    when p_lat is null or p_lng is null
      then false
    else earth_distance(
           ll_to_earth(p_lat, p_lng),
           ll_to_earth(
             (p_criteria -> 'location' ->> 'lat')::double precision,
             (p_criteria -> 'location' ->> 'lng')::double precision
           )
         ) <= (p_criteria -> 'location' ->> 'radius_miles')::double precision * 1609.344
  end;
$$;

-- Every criterion for one user against one room's criteria.
create or replace function public.user_meets_criteria(p_user uuid, p_criteria jsonb)
returns boolean language sql stable security definer set search_path = public as $$
  select
    criteria_allows_number(p_criteria, 'age',       u.age)
    and criteria_allows_number(p_criteria, 'height_cm', u.height_cm)
    and criteria_allows_text(p_criteria, 'gender',              u.gender)
    and criteria_allows_text(p_criteria, 'relationship_status', u.relationship_status)
    and criteria_allows_text(p_criteria, 'looking_for',         u.looking_for)
    -- JSON says "faith"; the column is spiritual_orientation.
    and criteria_allows_text(p_criteria, 'faith',               u.spiritual_orientation)
    and criteria_allows_text(p_criteria, 'children_status',     u.children_status)
    and criteria_allows_text(p_criteria, 'smoking',             u.smoking)
    and criteria_allows_text(p_criteria, 'drinking',            u.drinking)
    and criteria_allows_text(p_criteria, 'cannabis',            u.cannabis)
    and criteria_allows_location(p_criteria, u.latitude, u.longitude)
  from public.users u
  where u.id = p_user;
$$;

-- available_communities: unchanged kind/gender/status logic, with the
-- criteria pass ANDed on. Criteria narrow further, never widen.
create or replace function available_communities(p_user uuid)
returns setof public.communities language plpgsql stable security definer set search_path = public as $$
declare v_gender text; v_int text[]; v_status text;
  is_woman boolean; is_man boolean; is_nb boolean; wants_men boolean; wants_women boolean; wants_all boolean; v_eligible boolean;
begin
  select lower(coalesce(gender,'')), coalesce(interested_in, array[]::text[]), lower(coalesce(relationship_status,''))
    into v_gender, v_int, v_status from public.users where id = p_user;
  v_int := array(select lower(x) from unnest(v_int) as x);
  is_woman := v_gender = any (array['woman','women','female','f']);
  is_man   := v_gender = any (array['man','men','male','m']);
  is_nb    := v_gender = any (array['non-binary','nonbinary','nb','enby','non binary']);
  wants_all   := v_int && array['everyone','all','any','everybody'];
  wants_women := (v_int && array['woman','women','female','f']) or wants_all;
  wants_men   := (v_int && array['man','men','male','m']) or wants_all;
  -- Eligible when single/dating OR status not yet set (launch default so the
  -- Field is not empty for users who have not chosen a status).
  v_eligible := v_status in ('single','dating','');
  return query
  select c.* from public.communities c
  where c.is_active and (
    -- Grandfathering lives here, not in the app. FieldView renders exactly
    -- what this function returns, so an existing member has to appear in it
    -- or the room would vanish from their Field the moment they stop
    -- qualifying — the opposite of what grandfathering means.
    is_active_member(p_user, c.id)
    or (
      (
        c.kind = 'everyone'
        or (c.kind = 'seeking_connection' and v_eligible and (
             (c.slug='women-men' and ((is_woman and wants_men) or (is_man and wants_women) or is_nb))
          or (c.slug='women-women' and ((is_woman and wants_women) or is_nb))
          or (c.slug='men-men' and ((is_man and wants_men) or is_nb))
          or (c.slug='open-connections')
        ))
      )
      and user_meets_criteria(p_user, c.criteria)
    )
  )
  order by c.display_order;
end; $$;

grant  execute on function public.criteria_allows_text(jsonb, text, text)                    to authenticated;
revoke execute on function public.criteria_allows_text(jsonb, text, text)                    from public, anon;
grant  execute on function public.criteria_allows_number(jsonb, text, numeric)               to authenticated;
revoke execute on function public.criteria_allows_number(jsonb, text, numeric)               from public, anon;
grant  execute on function public.criteria_allows_location(jsonb, double precision, double precision) to authenticated;
revoke execute on function public.criteria_allows_location(jsonb, double precision, double precision) from public, anon;
grant  execute on function public.user_meets_criteria(uuid, jsonb)                           to authenticated;
revoke execute on function public.user_meets_criteria(uuid, jsonb)                           from public, anon;
