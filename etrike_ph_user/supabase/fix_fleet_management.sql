-- Sulong Ride — fleet management: extended vehicles, assignments, maintenance logs.
-- Run in Supabase SQL Editor after fix_driver_onboarding.sql

alter table public.vehicles
  add column if not exists color text,
  add column if not exists year_manufactured smallint,
  add column if not exists notes text,
  add column if not exists assigned_at timestamptz,
  add column if not exists last_maintenance_at timestamptz,
  add column if not exists next_maintenance_due date;

create table if not exists public.vehicle_assignments (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  driver_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'active'
    check (status in ('scheduled', 'active', 'ended', 'cancelled')),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  assigned_by uuid references auth.users (id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists vehicle_assignments_vehicle_idx on public.vehicle_assignments (vehicle_id, created_at desc);
create index if not exists vehicle_assignments_driver_idx on public.vehicle_assignments (driver_id, created_at desc);
create index if not exists vehicle_assignments_status_idx on public.vehicle_assignments (status);

create table if not exists public.vehicle_maintenance_logs (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  logged_by uuid references auth.users (id),
  maintenance_type text not null default 'general'
    check (maintenance_type in ('general', 'battery', 'tires', 'brakes', 'electrical', 'body', 'inspection')),
  description text not null,
  cost numeric(10, 2),
  odometer_km numeric(10, 1),
  performed_at timestamptz not null default now(),
  next_due_date date,
  created_at timestamptz not null default now()
);

create index if not exists vehicle_maintenance_vehicle_idx on public.vehicle_maintenance_logs (vehicle_id, performed_at desc);

alter table public.vehicle_assignments enable row level security;
alter table public.vehicle_maintenance_logs enable row level security;

drop policy if exists vehicle_assignments_operator_all on public.vehicle_assignments;
create policy vehicle_assignments_operator_all on public.vehicle_assignments
  for all to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid() and o.approval_status = 'approved'))
  with check (exists (select 1 from public.operators o where o.id = auth.uid() and o.approval_status = 'approved'));

drop policy if exists vehicle_assignments_driver_read on public.vehicle_assignments;
create policy vehicle_assignments_driver_read on public.vehicle_assignments
  for select to authenticated using (auth.uid() = driver_id);

drop policy if exists vehicle_maintenance_operator_all on public.vehicle_maintenance_logs;
create policy vehicle_maintenance_operator_all on public.vehicle_maintenance_logs
  for all to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid() and o.approval_status = 'approved'))
  with check (exists (select 1 from public.operators o where o.id = auth.uid() and o.approval_status = 'approved'));

drop policy if exists vehicles_driver_read_assigned on public.vehicles;
create policy vehicles_driver_read_assigned on public.vehicles
  for select to authenticated
  using (assigned_driver_id = auth.uid() or status = 'available');

grant select on public.vehicle_assignments to authenticated;
grant select, insert, update, delete on public.vehicle_maintenance_logs to authenticated;
grant select, insert, update, delete on public.vehicle_assignments to authenticated;

notify pgrst, 'reload schema';
