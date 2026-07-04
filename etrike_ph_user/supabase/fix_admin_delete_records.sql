-- Admin-only permanent delete for drivers and fleet units.
-- Run in Supabase SQL Editor after fix_operator_rbac.sql and fix_fleet_management.sql

create or replace function public.is_admin_operator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.operators o
    where o.id = auth.uid()
      and o.approval_status = 'approved'
      and o.role in ('admin', 'super_admin')
  );
$$;

grant execute on function public.is_admin_operator() to authenticated;

-- Permanently removes a driver: profile, onboarding, training, auth login, etc.
create or replace function public.admin_delete_driver(p_driver_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin_operator() then
    raise exception 'Only admin operators can delete driver records';
  end if;

  if p_driver_id is null then
    raise exception 'Driver id is required';
  end if;

  if exists (select 1 from public.operators where id = p_driver_id) then
    raise exception 'Cannot delete an operator account from driver delete';
  end if;

  if not exists (select 1 from public.drivers where id = p_driver_id) then
    raise exception 'Driver not found';
  end if;

  if exists (
    select 1
    from public.trips
    where driver_id = p_driver_id
      and status in ('accepted', 'ongoing')
  ) then
    raise exception 'Driver has an active trip. Complete or cancel it before deleting.';
  end if;

  update public.vehicles
  set
    assigned_driver_id = null,
    status = case when status = 'assigned' then 'available' else status end,
    assigned_at = null,
    updated_at = now()
  where assigned_driver_id = p_driver_id;

  update public.vehicle_assignments
  set
    status = 'ended',
    effective_to = coalesce(effective_to, now()),
    updated_at = now()
  where driver_id = p_driver_id
    and status in ('active', 'scheduled');

  delete from public.driver_attendance where driver_id = p_driver_id;
  delete from public.leave_requests where driver_id = p_driver_id;

  delete from public.drivers where id = p_driver_id;

  delete from auth.users where id = p_driver_id;
end;
$$;

grant execute on function public.admin_delete_driver(uuid) to authenticated;

-- Permanently removes a fleet unit and its assignment/maintenance history.
create or replace function public.admin_delete_vehicle(p_vehicle_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin_operator() then
    raise exception 'Only admin operators can delete fleet units';
  end if;

  if p_vehicle_id is null then
    raise exception 'Vehicle id is required';
  end if;

  if not exists (select 1 from public.vehicles where id = p_vehicle_id) then
    raise exception 'Vehicle not found';
  end if;

  if exists (
    select 1
    from public.trips t
    join public.vehicles v on v.assigned_driver_id = t.driver_id
    where v.id = p_vehicle_id
      and t.status in ('accepted', 'ongoing')
  ) then
    raise exception 'Assigned driver has an active trip. Resolve the trip before deleting this unit.';
  end if;

  update public.vehicle_assignments
  set
    status = 'ended',
    effective_to = coalesce(effective_to, now()),
    updated_at = now()
  where vehicle_id = p_vehicle_id
    and status in ('active', 'scheduled');

  update public.vehicles
  set
    assigned_driver_id = null,
    status = 'available',
    assigned_at = null,
    updated_at = now()
  where id = p_vehicle_id;

  update public.driver_documents
  set vehicle_id = null
  where vehicle_id = p_vehicle_id;

  if to_regclass('public.payroll_records') is not null then
    update public.payroll_records
    set vehicle_id = null
    where vehicle_id = p_vehicle_id;
  end if;

  delete from public.vehicles where id = p_vehicle_id;
end;
$$;

grant execute on function public.admin_delete_vehicle(uuid) to authenticated;

notify pgrst, 'reload schema';
