-- Run ALL of this once in Supabase → SQL Editor (same project as keys.dart).
-- Fixes: PGRST204 is_online, driver RLS, incoming trip SELECT, PostgREST cache reload.
-- Also run etrike_ph_user/supabase/fix_trips_rls.sql if rider booking fails with 42501.

-- ---------------------------------------------------------------------------
-- 1) drivers columns (is_online, location, etc.)
-- ---------------------------------------------------------------------------
create table if not exists public.drivers (
  id uuid primary key references auth.users (id) on delete cascade
);

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

drop policy if exists "drivers_select_authenticated" on public.drivers;
create policy "drivers_select_authenticated"
  on public.drivers for select to authenticated
  using (true);

drop policy if exists "drivers_insert_own" on public.drivers;
create policy "drivers_insert_own"
  on public.drivers for insert to authenticated
  with check (auth.uid() = id);

drop policy if exists "drivers_update_own" on public.drivers;
create policy "drivers_update_own"
  on public.drivers for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

grant select, insert, update on table public.drivers to authenticated;

-- ---------------------------------------------------------------------------
-- 2a) trips columns used by driver complete flow
-- ---------------------------------------------------------------------------
alter table public.trips add column if not exists distance_km numeric;
alter table public.trips add column if not exists completed_at timestamptz;

-- ---------------------------------------------------------------------------
-- 2b) trips RLS — riders insert; drivers read open requests + accept
-- ---------------------------------------------------------------------------
alter table public.trips enable row level security;

drop policy if exists "trips_insert_own" on public.trips;
create policy "trips_insert_own"
  on public.trips for insert to authenticated
  with check (auth.uid() = rider_id);

drop policy if exists "trips_select_participant" on public.trips;
create policy "trips_select_participant"
  on public.trips for select to authenticated
  using (auth.uid() = rider_id or auth.uid() = driver_id);

drop policy if exists "trips_update_participant" on public.trips;
create policy "trips_update_participant"
  on public.trips for update to authenticated
  using (auth.uid() = rider_id or auth.uid() = driver_id)
  with check (auth.uid() = rider_id or auth.uid() = driver_id);

drop policy if exists "trips_select_requested" on public.trips;
create policy "trips_select_requested"
  on public.trips for select to authenticated
  using (status = 'requested');

drop policy if exists "trips_accept_requested" on public.trips;
create policy "trips_accept_requested"
  on public.trips for update to authenticated
  using (
    status = 'requested'
    and driver_id is null
    and exists (select 1 from public.drivers d where d.id = auth.uid())
  )
  with check (auth.uid() = driver_id);

grant select, insert, update on table public.trips to authenticated;

-- ---------------------------------------------------------------------------
-- 3) messages — in-trip chat (rider ↔ driver)
-- ---------------------------------------------------------------------------
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  sender_role text not null check (sender_role in ('rider', 'driver')),
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists messages_trip_id_created_at_idx
  on public.messages (trip_id, created_at);

alter table public.messages enable row level security;

drop policy if exists "messages_select_trip_participant" on public.messages;
create policy "messages_select_trip_participant"
  on public.messages for select to authenticated
  using (
    exists (
      select 1 from public.trips t
      where t.id = trip_id
        and (t.rider_id = auth.uid() or t.driver_id = auth.uid())
    )
  );

drop policy if exists "messages_insert_trip_participant" on public.messages;
create policy "messages_insert_trip_participant"
  on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.trips t
      where t.id = trip_id
        and (t.rider_id = auth.uid() or t.driver_id = auth.uid())
    )
  );

grant select, insert on table public.messages to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Realtime (optional but recommended — poll still works every 4s)
-- ---------------------------------------------------------------------------
-- Dashboard → Database → Publications → supabase_realtime → add `trips`, `drivers`, `messages`
-- Or uncomment if not already added:
-- alter publication supabase_realtime add table public.trips;

notify pgrst, 'reload schema';

select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'drivers'
order by ordinal_position;
