# Admin-authored room access criteria — design (2026-08-04)

Let an admin restrict who can discover and join a room, by any profile
attribute — including "within 100 miles of Washington" — without shipping an
app update.

## Why

Room eligibility is hardcoded today in `available_communities()`
(`supabase/migrations/20260609130000_the_field.sql:54`), which reads only
gender, `interested_in`, and `relationship_status`. Any new kind of room needs
a migration and, if the app must understand it, an App Store release. Moving
the rules into data removes both.

## Scope decisions already made

- **Grandfathering:** criteria gate discovery and joining only. Existing
  members keep access.
- **Location is real radius math**, backed by new coordinates on `users`.
- **A missing profile attribute excludes.** See §4 — this is deliberate and is
  the opposite of the roster filter's rule.

---

## 1. Storage

One new column:

```sql
alter table public.communities
  add column if not exists criteria jsonb not null default '{}'::jsonb;
```

An absent key means no constraint. An empty array means no constraint. All
present keys are ANDed.

```json
{
  "age":                 { "min": 25, "max": 40 },
  "height_cm":           { "min": 160, "max": 200 },
  "gender":              ["female"],
  "relationship_status": ["single"],
  "looking_for":         ["Marriage"],
  "faith":               ["Christianity"],
  "children_status":     ["Want someday"],
  "smoking":             ["Never"],
  "drinking":            ["Never", "Socially"],
  "cannabis":            ["Never"],
  "location": {
    "lat": 38.9072, "lng": -77.0369,
    "radius_miles": 100, "label": "Washington, DC"
  }
}
```

`faith` maps to `users.spiritual_orientation`; the JSON key is the user-facing
word. Every array-valued key is matched case-insensitively against the user's
single stored value.

A `jsonb` column rather than a `community_criteria` table: the criteria are
always read as a whole, never queried across rooms, and the set of attributes
changes as the profile does. A table would mean a migration per new attribute.

## 2. Gating

`available_communities(p_user uuid)` gains a criteria pass ANDed onto its
existing logic. The existing gender / `interested_in` / `relationship_status` /
`kind` behaviour is **unchanged** — criteria narrow further, never widen.

**The iOS app needs no changes to enforce any of this.** `FieldView` renders
whatever the function returns, and `can_join_community()` already delegates to
it, so joining is gated by the same rule as discovery.

Grandfathering therefore has to live inside the same function: `FieldViewModel`
sources rooms *only* from `available_communities()`, so an existing member must
appear in its results or the room would disappear from their Field the moment
they stopped qualifying. The function returns a room when the user
`is_active_member` of it **or** passes the eligibility and criteria checks.

Rooms a user doesn't qualify for simply don't appear. No "locked room" state,
no explanation — matching how ineligible rooms behave today.

## 3. Location

```sql
create extension if not exists cube;
create extension if not exists earthdistance;

alter table public.users
  add column if not exists latitude  double precision,
  add column if not exists longitude double precision;

create index if not exists users_earth_idx
  on public.users using gist (ll_to_earth(latitude, longitude))
  where latitude is not null and longitude is not null;
```

Distance uses `earth_distance(ll_to_earth(u.latitude, u.longitude),
ll_to_earth(c.lat, c.lng))`, which returns metres; the criterion is in miles,
so compare against `radius_miles * 1609.344`.

**Backfill happens on-device.** Onboarding already geocodes to validate the
location string (it uses `MKGeocodingRequest`). The app geocodes and writes
coordinates for any signed-in user who has a `location` but no `latitude`, once
per launch, silently. No server-side geocoding key, no batch job.

Users with no coordinates match no location-restricted room. That is the
correct-but-surprising consequence of §4, and it resolves itself the first time
they open the updated app.

## 4. Missing attributes exclude

A user whose `spiritual_orientation` is null does **not** qualify for a
`faith: ["Christianity"]` room.

This is the opposite of `RoomMemberFilter.matches`, where a blank attribute
never excludes. The two rules serve different jobs: the roster filter is a
browsing aid over people you can already see, so leniency costs nothing;
criteria are an access restriction, and the lenient rule would let anyone into
every restricted room by leaving fields blank — exactly inverting the feature.

Practical consequence worth stating plainly: **restricted rooms will look empty
to users with thin profiles.** That is the intended behaviour, not a bug.

## 5. Admin panel

The room form (`admin/app.js`, `openRoomForm`) gains a collapsible
**Restrictions** section:

- Age min/max, height min/max — number inputs.
- Gender, relationship status, looking for, faith, children, smoking,
  drinking, cannabis — multi-selects, using the same vocabulary the app
  stores.
- Location — a text field, a radius in miles, and a **Look up** button.

The panel already ships a `.gitignore`d `config.js` holding the service key and
talks only to Supabase. The lookup adds one external dependency:
**OpenStreetMap Nominatim** (free, no key). It resolves the typed place to
coordinates, and the panel **shows the resolved point and label for the admin
to confirm before saving** — never saving a silently-guessed location. Requests
send a descriptive `User-Agent` per Nominatim's usage policy.

If a room has no restrictions the section stays collapsed and `criteria`
stays `{}`, so existing rooms are untouched.

The form writes `criteria` through the existing room save path; no new endpoint.

## 6. Migration safety

- The column has a default, so every existing room gets `{}` and remains
  visible to exactly who it was visible to before.
- `available_communities()` is replaced with `create or replace`, keeping its
  signature, `SECURITY DEFINER`, pinned `search_path`, and grants.
- Applied via the dashboard SQL editor with `execute_sql`, matching how this
  project applies SQL (the repo's migration history is not in sync with the
  remote).

## 7. Testing

SQL-level, run against the live database with throwaway rows:

- A room with `{}` is visible to everyone it was visible to before.
- An age-restricted room excludes a user outside the band, includes one inside.
- A faith-restricted room excludes a user with a null `spiritual_orientation`.
- A location-restricted room includes a user 50 miles away and excludes one 500
  miles away.
- A user with null coordinates sees no location-restricted room.
- A grandfathered member who no longer qualifies still returns true from
  `can_join_community()` — or, more precisely, retains their membership row and
  can still open the room.

Admin-panel behaviour is verified by hand: save criteria, reload, confirm the
JSON round-trips.

## 8. Out of scope

- Any in-app UI for criteria. Admins author them; users only see the effect.
- Telling a user *why* a room is hidden.
- Ejecting members who stop qualifying.
- Per-room custom questions or manual approval queues.
