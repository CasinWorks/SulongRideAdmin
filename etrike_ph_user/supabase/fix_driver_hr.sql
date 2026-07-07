-- Driver HR: attendance (time in/out), leave requests (VL/SL).
-- Run in Supabase Dashboard → SQL Editor after fix_carmona_pilot.sql.

-- ---------------------------------------------------------------------------
-- Attendance
-- ---------------------------------------------------------------------------
create table if not exists public.driver_attendance (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers (id) on delete cascade,
  clock_in timestamptz not null default now(),
  clock_out timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists driver_attendance_driver_id_idx
  on public.driver_attendance (driver_id, clock_in desc);

alter table public.driver_attendance enable row level security;

drop policy if exists "attendance_select_own" on public.driver_attendance;
create policy "attendance_select_own"
  on public.driver_attendance for select to authenticated
  using (auth.uid() = driver_id);

drop policy if exists "attendance_select_admin" on public.driver_attendance;
create policy "attendance_select_admin"
  on public.driver_attendance for select to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()));

drop policy if exists "attendance_insert_own" on public.driver_attendance;
create policy "attendance_insert_own"
  on public.driver_attendance for insert to authenticated
  with check (auth.uid() = driver_id);

drop policy if exists "attendance_update_own" on public.driver_attendance;
create policy "attendance_update_own"
  on public.driver_attendance for update to authenticated
  using (auth.uid() = driver_id)
  with check (auth.uid() = driver_id);

drop policy if exists "attendance_update_admin" on public.driver_attendance;
create policy "attendance_update_admin"
  on public.driver_attendance for update to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()));

-- ---------------------------------------------------------------------------
-- Leave requests (VL / SL)
-- ---------------------------------------------------------------------------
create table if not exists public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers (id) on delete cascade,
  leave_type text not null check (leave_type in ('VL', 'SL')),
  start_date date not null,
  end_date date not null,
  reason text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists leave_requests_driver_id_idx
  on public.leave_requests (driver_id, created_at desc);

alter table public.leave_requests enable row level security;

drop policy if exists "leave_select_own" on public.leave_requests;
create policy "leave_select_own"
  on public.leave_requests for select to authenticated
  using (auth.uid() = driver_id);

drop policy if exists "leave_select_admin" on public.leave_requests;
create policy "leave_select_admin"
  on public.leave_requests for select to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()));

drop policy if exists "leave_insert_own" on public.leave_requests;
create policy "leave_insert_own"
  on public.leave_requests for insert to authenticated
  with check (auth.uid() = driver_id and status = 'pending');

drop policy if exists "leave_update_own" on public.leave_requests;
create policy "leave_update_own"
  on public.leave_requests for update to authenticated
  using (auth.uid() = driver_id)
  with check (auth.uid() = driver_id);

drop policy if exists "leave_update_admin" on public.leave_requests;
create policy "leave_update_admin"
  on public.leave_requests for update to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()));

-- Operators can read trips for driver stats / HR reporting
drop policy if exists "trips_select_admin" on public.trips;
create policy "trips_select_admin"
  on public.trips for select to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()));

grant select, insert, update on public.driver_attendance to authenticated;
grant select, insert, update on public.leave_requests to authenticated;

notify pgrst, 'reload schema';
