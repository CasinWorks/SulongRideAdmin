-- Run in Supabase → SQL Editor (fixes PGRST204: distance_km column missing)

-- If you already have `trips`, add the missing column:
alter table public.trips
  add column if not exists distance_km numeric;

-- Optional: full table if `trips` does not exist yet
create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid not null references auth.users (id) on delete cascade,
  driver_id uuid references auth.users (id) on delete set null,
  pickup_address text not null,
  dropoff_address text not null,
  pickup_lat double precision not null,
  pickup_lng double precision not null,
  dropoff_lat double precision not null,
  dropoff_lng double precision not null,
  status text not null default 'requested',
  fare numeric not null,
  distance_km numeric,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

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

-- Drivers can read open requests (for driver app)
drop policy if exists "trips_select_requested" on public.trips;
create policy "trips_select_requested"
  on public.trips for select to authenticated
  using (status = 'requested');
