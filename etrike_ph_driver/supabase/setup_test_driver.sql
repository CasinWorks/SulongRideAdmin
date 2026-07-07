-- Run in Supabase → SQL Editor before testing driver + rider together.
-- Project must match etrike_ph_user / etrike_ph_driver keys.dart.

-- ---------------------------------------------------------------------------
-- 1) `drivers` table (if missing)
-- ---------------------------------------------------------------------------
create table if not exists public.drivers (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  email text not null default '',
  phone text,
  profile_photo_url text,
  trike_plate_number text,
  trike_model text,
  is_available boolean not null default false,
  is_online boolean not null default false,
  current_lat double precision,
  current_lng double precision,
  fcm_token text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Backfill columns when `drivers` already existed without online/location fields
alter table public.drivers add column if not exists full_name text not null default '';
alter table public.drivers add column if not exists email text not null default '';
alter table public.drivers add column if not exists phone text;
alter table public.drivers add column if not exists profile_photo_url text;
alter table public.drivers add column if not exists trike_plate_number text;
alter table public.drivers add column if not exists trike_model text;
alter table public.drivers add column if not exists is_available boolean not null default false;
alter table public.drivers add column if not exists is_online boolean not null default false;
alter table public.drivers add column if not exists current_lat double precision;
alter table public.drivers add column if not exists current_lng double precision;
alter table public.drivers add column if not exists fcm_token text;
alter table public.drivers add column if not exists created_at timestamptz not null default now();
alter table public.drivers add column if not exists updated_at timestamptz not null default now();

alter table public.drivers enable row level security;

-- Drivers read all rows (rider app shows nearby drivers on map)
drop policy if exists "drivers_select_authenticated" on public.drivers;
create policy "drivers_select_authenticated"
  on public.drivers for select to authenticated
  using (true);

-- Driver inserts own row on registration (app upsert after signUp)
drop policy if exists "drivers_insert_own" on public.drivers;
create policy "drivers_insert_own"
  on public.drivers for insert to authenticated
  with check (auth.uid() = id);

-- Driver updates own profile / online / location
drop policy if exists "drivers_update_own" on public.drivers;
create policy "drivers_update_own"
  on public.drivers for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

grant select, insert, update on table public.drivers to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Trip accept: driver assigns self while trip is still `requested`
--    (fixes RLS 42501 when driver_id was null on update)
-- ---------------------------------------------------------------------------
drop policy if exists "trips_accept_requested" on public.trips;
create policy "trips_accept_requested"
  on public.trips for update to authenticated
  using (
    status = 'requested'
    and driver_id is null
    and exists (select 1 from public.drivers d where d.id = auth.uid())
  )
  with check (auth.uid() = driver_id);

grant update on table public.trips to authenticated;

-- Drivers read open requests (incoming trip sheet + Realtime/poll)
drop policy if exists "trips_select_requested" on public.trips;
create policy "trips_select_requested"
  on public.trips for select to authenticated
  using (status = 'requested');

grant select on table public.trips to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Backfill drivers from auth (optional)
--    auth user + role=driver metadata but no public.drivers row
-- ---------------------------------------------------------------------------
-- See: supabase/backfill_drivers_from_auth.sql

-- ---------------------------------------------------------------------------
-- 4) Manual link (optional) — prefer in-app Register on the driver app
-- ---------------------------------------------------------------------------
-- Step A — In Supabase Dashboard → Authentication → Users:
--   • Add user (or use existing), e.g. driver-test@yourdomain.com
--   • Copy the user's UUID from the users list.
--
-- Step B — Replace placeholders below and run:

/*
insert into public.drivers (
  id,
  full_name,
  email,
  phone,
  trike_plate_number,
  trike_model,
  is_available,
  is_online
)
values (
  'PASTE_AUTH_USER_UUID_HERE'::uuid,
  'Test Driver',
  'driver-test@yourdomain.com',
  null,
  'ABC-1234',
  'Etrike',
  false,
  false
)
on conflict (id) do update set
  full_name = excluded.full_name,
  email = excluded.email,
  trike_plate_number = excluded.trike_plate_number,
  trike_model = excluded.trike_model;
*/

-- ---------------------------------------------------------------------------
-- 5) Realtime — required for live incoming trips (poll still works without it)
--    Dashboard → Database → Publications → supabase_realtime → add:
--      trips, drivers, messages
--    Or SQL: alter publication supabase_realtime add table public.trips;
-- ---------------------------------------------------------------------------

notify pgrst, 'reload schema';
