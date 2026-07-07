-- Run in Supabase → SQL Editor (fixes: row-level security policy for table "trips", code 42501)

alter table public.trips enable row level security;

-- Rider: create a trip for themselves
drop policy if exists "trips_insert_own" on public.trips;
create policy "trips_insert_own"
  on public.trips
  for insert
  to authenticated
  with check (auth.uid() = rider_id);

-- Rider/driver: read trips they participate in (needed after insert .select())
drop policy if exists "trips_select_participant" on public.trips;
create policy "trips_select_participant"
  on public.trips
  for select
  to authenticated
  using (auth.uid() = rider_id or auth.uid() = driver_id);

-- Operators (admin dashboard): read all trips for KPIs and driver profiles.
drop policy if exists "trips_select_admin" on public.trips;
create policy "trips_select_admin"
  on public.trips for select to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()));

-- Rider: cancel while still requested; driver: updates when assigned
drop policy if exists "trips_update_participant" on public.trips;
create policy "trips_update_participant"
  on public.trips
  for update
  to authenticated
  using (auth.uid() = rider_id or auth.uid() = driver_id)
  with check (auth.uid() = rider_id or auth.uid() = driver_id);

-- Driver app: see open ride requests
drop policy if exists "trips_select_requested" on public.trips;
create policy "trips_select_requested"
  on public.trips
  for select
  to authenticated
  using (status = 'requested');

grant select, insert, update on table public.trips to authenticated;

notify pgrst, 'reload schema';
