-- Sulong Ride — add hr + dispatcher operator roles with scoped RLS writes.
-- Run after fix_operator_rbac_viewer.sql

-- ---------------------------------------------------------------------------
-- 1) Extend operators.role
-- ---------------------------------------------------------------------------
alter table public.operators
  drop constraint if exists operators_role_check;

alter table public.operators
  add constraint operators_role_check
  check (role in ('super_admin', 'admin', 'viewer', 'hr', 'dispatcher'));

drop policy if exists "operators_insert_self_pending" on public.operators;
create policy "operators_insert_self_pending"
  on public.operators for insert to authenticated
  with check (
    auth.uid() = id
    and approval_status = 'pending'
    and role in ('admin', 'viewer', 'hr', 'dispatcher')
  );

-- ---------------------------------------------------------------------------
-- 2) Role helpers
-- ---------------------------------------------------------------------------
create or replace function public.is_operator_reader()
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
      and o.role in ('super_admin', 'admin', 'viewer', 'hr', 'dispatcher')
  );
$$;

create or replace function public.is_operator_admin_writer()
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
      and o.role in ('super_admin', 'admin')
  );
$$;

create or replace function public.is_dispatcher_writer()
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
      and o.role = 'dispatcher'
  );
$$;

create or replace function public.is_hr_writer()
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
      and o.role = 'hr'
  );
$$;

create or replace function public.is_operator_writer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_operator_admin_writer();
$$;

grant execute on function public.is_operator_admin_writer() to authenticated;
grant execute on function public.is_dispatcher_writer() to authenticated;
grant execute on function public.is_hr_writer() to authenticated;

-- ---------------------------------------------------------------------------
-- 3) audit_logs.actor_role — allow hr + dispatcher
-- ---------------------------------------------------------------------------
alter table public.audit_logs
  drop constraint if exists audit_logs_actor_role_check;

alter table public.audit_logs
  add constraint audit_logs_actor_role_check
  check (
    actor_role in (
      'operator',
      'driver',
      'rider',
      'super_admin',
      'admin',
      'viewer',
      'hr',
      'dispatcher'
    )
  );

-- ---------------------------------------------------------------------------
-- 4) Scoped write policies (select stays is_operator_reader)
-- ---------------------------------------------------------------------------

-- Drivers / trips — admin + dispatcher
drop policy if exists "drivers_update_admin" on public.drivers;
create policy "drivers_update_admin" on public.drivers
  for update to authenticated
  using (public.is_operator_admin_writer() or public.is_dispatcher_writer())
  with check (public.is_operator_admin_writer() or public.is_dispatcher_writer());

drop policy if exists "trips_update_admin" on public.trips;
create policy "trips_update_admin" on public.trips
  for update to authenticated
  using (public.is_operator_admin_writer() or public.is_dispatcher_writer())
  with check (public.is_operator_admin_writer() or public.is_dispatcher_writer());

-- Fare — admin only
drop policy if exists "fare_config_admin_insert" on public.fare_config;
drop policy if exists "fare_config_admin_update" on public.fare_config;
create policy "fare_config_admin_insert" on public.fare_config
  for insert to authenticated with check (public.is_operator_admin_writer());
create policy "fare_config_admin_update" on public.fare_config
  for update to authenticated
  using (public.is_operator_admin_writer())
  with check (public.is_operator_admin_writer());

drop policy if exists "fare_schedules_operator_insert" on public.fare_schedules;
drop policy if exists "fare_schedules_operator_update" on public.fare_schedules;
drop policy if exists "fare_schedules_operator_delete" on public.fare_schedules;
create policy "fare_schedules_operator_insert" on public.fare_schedules
  for insert to authenticated with check (public.is_operator_admin_writer());
create policy "fare_schedules_operator_update" on public.fare_schedules
  for update to authenticated
  using (public.is_operator_admin_writer())
  with check (public.is_operator_admin_writer());
create policy "fare_schedules_operator_delete" on public.fare_schedules
  for delete to authenticated using (public.is_operator_admin_writer());

-- HR — admin + hr
drop policy if exists "attendance_update_admin" on public.driver_attendance;
create policy "attendance_update_admin" on public.driver_attendance
  for update to authenticated
  using (public.is_operator_admin_writer() or public.is_hr_writer())
  with check (public.is_operator_admin_writer() or public.is_hr_writer());

drop policy if exists "leave_update_admin" on public.leave_requests;
create policy "leave_update_admin" on public.leave_requests
  for update to authenticated
  using (public.is_operator_admin_writer() or public.is_hr_writer())
  with check (public.is_operator_admin_writer() or public.is_hr_writer());

-- Fleet + onboarding — admin + dispatcher
drop policy if exists vehicles_operator_insert on public.vehicles;
drop policy if exists vehicles_operator_update on public.vehicles;
drop policy if exists vehicles_operator_delete on public.vehicles;
create policy vehicles_operator_insert on public.vehicles
  for insert to authenticated
  with check (public.is_operator_admin_writer() or public.is_dispatcher_writer());
create policy vehicles_operator_update on public.vehicles
  for update to authenticated
  using (public.is_operator_admin_writer() or public.is_dispatcher_writer())
  with check (public.is_operator_admin_writer() or public.is_dispatcher_writer());
create policy vehicles_operator_delete on public.vehicles
  for delete to authenticated
  using (public.is_operator_admin_writer() or public.is_dispatcher_writer());

drop policy if exists driver_documents_operator_write on public.driver_documents;
create policy driver_documents_operator_write on public.driver_documents
  for all to authenticated
  using (public.is_operator_admin_writer() or public.is_dispatcher_writer())
  with check (public.is_operator_admin_writer() or public.is_dispatcher_writer());

drop policy if exists hiring_pipeline_operator_write on public.driver_hiring_pipeline;
create policy hiring_pipeline_operator_write on public.driver_hiring_pipeline
  for all to authenticated
  using (public.is_operator_admin_writer() or public.is_dispatcher_writer())
  with check (public.is_operator_admin_writer() or public.is_dispatcher_writer());

drop policy if exists onboarding_timeline_operator_write on public.onboarding_timeline;
create policy onboarding_timeline_operator_write on public.onboarding_timeline
  for all to authenticated
  using (public.is_operator_admin_writer() or public.is_dispatcher_writer())
  with check (public.is_operator_admin_writer() or public.is_dispatcher_writer());

drop policy if exists registration_drafts_operator_write on public.driver_registration_drafts;
create policy registration_drafts_operator_write on public.driver_registration_drafts
  for all to authenticated
  using (public.is_operator_admin_writer() or public.is_dispatcher_writer())
  with check (public.is_operator_admin_writer() or public.is_dispatcher_writer());

drop policy if exists driver_documents_storage_operator_write on storage.objects;
create policy driver_documents_storage_operator_write on storage.objects
  for all to authenticated
  using (
    bucket_id = 'driver-documents'
    and (public.is_operator_admin_writer() or public.is_dispatcher_writer())
  )
  with check (
    bucket_id = 'driver-documents'
    and (public.is_operator_admin_writer() or public.is_dispatcher_writer())
  );

drop policy if exists vehicle_assignments_operator_write on public.vehicle_assignments;
create policy vehicle_assignments_operator_write on public.vehicle_assignments
  for all to authenticated
  using (public.is_operator_admin_writer() or public.is_dispatcher_writer())
  with check (public.is_operator_admin_writer() or public.is_dispatcher_writer());

drop policy if exists vehicle_maintenance_operator_write on public.vehicle_maintenance_logs;
create policy vehicle_maintenance_operator_write on public.vehicle_maintenance_logs
  for all to authenticated
  using (public.is_operator_admin_writer() or public.is_dispatcher_writer())
  with check (public.is_operator_admin_writer() or public.is_dispatcher_writer());

drop policy if exists driver_training_operator_write on public.driver_training;
create policy driver_training_operator_write on public.driver_training
  for all to authenticated
  using (public.is_operator_admin_writer() or public.is_dispatcher_writer())
  with check (public.is_operator_admin_writer() or public.is_dispatcher_writer());

-- Payroll — admin + hr
drop policy if exists payroll_config_operator_write on public.payroll_deduction_configs;
create policy payroll_config_operator_write on public.payroll_deduction_configs
  for all to authenticated
  using (public.is_operator_admin_writer() or public.is_hr_writer())
  with check (public.is_operator_admin_writer() or public.is_hr_writer());

drop policy if exists cash_advances_operator_write on public.cash_advances;
create policy cash_advances_operator_write on public.cash_advances
  for all to authenticated
  using (public.is_operator_admin_writer() or public.is_hr_writer())
  with check (public.is_operator_admin_writer() or public.is_hr_writer());

drop policy if exists payroll_records_operator_write on public.payroll_records;
create policy payroll_records_operator_write on public.payroll_records
  for all to authenticated
  using (public.is_operator_admin_writer() or public.is_hr_writer())
  with check (public.is_operator_admin_writer() or public.is_hr_writer());

notify pgrst, 'reload schema';
