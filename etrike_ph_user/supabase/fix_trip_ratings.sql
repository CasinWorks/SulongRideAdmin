-- Trip ratings: columns, operator read access, rider submit policy.
-- Run in Supabase Dashboard → SQL Editor (safe to re-run).

alter table public.trips
  add column if not exists rating smallint check (rating >= 1 and rating <= 5),
  add column if not exists review_text text,
  add column if not exists complaint_tags text[] default '{}',
  add column if not exists rating_submitted_at timestamptz,
  add column if not exists review_acknowledged_at timestamptz;

create index if not exists trips_driver_completed_idx
  on public.trips (driver_id, completed_at desc)
  where status = 'completed';

create index if not exists trips_rating_idx
  on public.trips (driver_id, rating)
  where rating is not null;

-- Operators read all trips (admin dashboard KPIs / driver profile).
drop policy if exists "trips_select_admin" on public.trips;
create policy "trips_select_admin"
  on public.trips for select to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()));

-- Riders may submit a rating on their own completed trips.
drop policy if exists "trips_rate_rider" on public.trips;
create policy "trips_rate_rider"
  on public.trips for update to authenticated
  using (
    auth.uid() = rider_id
    and status = 'completed'
    and rating is null
  )
  with check (
    auth.uid() = rider_id
    and status = 'completed'
    and rating is not null
    and rating between 1 and 5
  );

-- Operators may acknowledge low-rating reviews (admin workflow).
drop policy if exists "trips_update_admin" on public.trips;
create policy "trips_update_admin"
  on public.trips for update to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()))
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));

notify pgrst, 'reload schema';
