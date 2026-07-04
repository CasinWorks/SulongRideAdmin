-- Sulong Ride — viewer read-only operator RBAC.
-- Run after fix_operator_rbac.sql, fix_fleet_management.sql, fix_payroll.sql, fix_driver_training.sql
--
-- Adds is_operator_reader() / is_operator_writer() and splits admin table RLS so
-- approved viewers can SELECT but not INSERT/UPDATE/DELETE operational data.

-- ---------------------------------------------------------------------------
-- 1) Helper functions
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
      and o.role in ('super_admin', 'admin', 'viewer')
  );
$$;

create or replace function public.is_operator_writer()
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

grant execute on function public.is_operator_reader() to authenticated;
grant execute on function public.is_operator_writer() to authenticated;

-- Backward-compatible alias: approved operators including viewers (read paths).
create or replace function public.is_approved_operator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_operator_reader();
$$;

-- ---------------------------------------------------------------------------
-- 2) Core admin tables (fix_operator_rbac.sql)
-- ---------------------------------------------------------------------------

-- fare_config
drop policy if exists "fare_config_admin_update" on public.fare_config;
drop policy if exists "fare_config_admin_insert" on public.fare_config;
drop policy if exists fare_config_operator_select on public.fare_config;
create policy fare_config_operator_select on public.fare_config
  for select to authenticated using (public.is_operator_reader());
create policy "fare_config_admin_insert" on public.fare_config
  for insert to authenticated with check (public.is_operator_writer());
create policy "fare_config_admin_update" on public.fare_config
  for update to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

-- drivers
drop policy if exists "drivers_select_admin" on public.drivers;
drop policy if exists "drivers_update_admin" on public.drivers;
create policy "drivers_select_admin" on public.drivers
  for select to authenticated using (public.is_operator_reader());
create policy "drivers_update_admin" on public.drivers
  for update to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

-- trips
drop policy if exists "trips_select_admin" on public.trips;
drop policy if exists "trips_update_admin" on public.trips;
create policy "trips_select_admin" on public.trips
  for select to authenticated using (public.is_operator_reader());
create policy "trips_update_admin" on public.trips
  for update to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

-- audit_logs (read only for operators)
drop policy if exists "audit_select_admin" on public.audit_logs;
create policy "audit_select_admin" on public.audit_logs
  for select to authenticated using (public.is_operator_reader());

-- HR
drop policy if exists "attendance_select_admin" on public.driver_attendance;
drop policy if exists "attendance_update_admin" on public.driver_attendance;
create policy "attendance_select_admin" on public.driver_attendance
  for select to authenticated using (public.is_operator_reader());
create policy "attendance_update_admin" on public.driver_attendance
  for update to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

drop policy if exists "leave_select_admin" on public.leave_requests;
drop policy if exists "leave_update_admin" on public.leave_requests;
create policy "leave_select_admin" on public.leave_requests
  for select to authenticated using (public.is_operator_reader());
create policy "leave_update_admin" on public.leave_requests
  for update to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

-- Onboarding tables
drop policy if exists vehicles_operator_all on public.vehicles;
drop policy if exists vehicles_operator_select on public.vehicles;
drop policy if exists vehicles_operator_insert on public.vehicles;
drop policy if exists vehicles_operator_update on public.vehicles;
drop policy if exists vehicles_operator_delete on public.vehicles;
create policy vehicles_operator_select on public.vehicles
  for select to authenticated using (public.is_operator_reader());
create policy vehicles_operator_insert on public.vehicles
  for insert to authenticated with check (public.is_operator_writer());
create policy vehicles_operator_update on public.vehicles
  for update to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());
create policy vehicles_operator_delete on public.vehicles
  for delete to authenticated using (public.is_operator_writer());

drop policy if exists driver_documents_operator_all on public.driver_documents;
drop policy if exists driver_documents_operator_select on public.driver_documents;
drop policy if exists driver_documents_operator_write on public.driver_documents;
create policy driver_documents_operator_select on public.driver_documents
  for select to authenticated using (public.is_operator_reader());
create policy driver_documents_operator_write on public.driver_documents
  for all to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

drop policy if exists hiring_pipeline_operator_all on public.driver_hiring_pipeline;
drop policy if exists hiring_pipeline_operator_select on public.driver_hiring_pipeline;
drop policy if exists hiring_pipeline_operator_write on public.driver_hiring_pipeline;
create policy hiring_pipeline_operator_select on public.driver_hiring_pipeline
  for select to authenticated using (public.is_operator_reader());
create policy hiring_pipeline_operator_write on public.driver_hiring_pipeline
  for all to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

drop policy if exists onboarding_timeline_operator_all on public.onboarding_timeline;
drop policy if exists onboarding_timeline_operator_select on public.onboarding_timeline;
drop policy if exists onboarding_timeline_operator_write on public.onboarding_timeline;
create policy onboarding_timeline_operator_select on public.onboarding_timeline
  for select to authenticated using (public.is_operator_reader());
create policy onboarding_timeline_operator_write on public.onboarding_timeline
  for all to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

drop policy if exists registration_drafts_operator_all on public.driver_registration_drafts;
drop policy if exists registration_drafts_operator_select on public.driver_registration_drafts;
drop policy if exists registration_drafts_operator_write on public.driver_registration_drafts;
create policy registration_drafts_operator_select on public.driver_registration_drafts
  for select to authenticated using (public.is_operator_reader());
create policy registration_drafts_operator_write on public.driver_registration_drafts
  for all to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

-- Storage (driver documents bucket) — operators read; writers mutate
drop policy if exists driver_documents_storage_operator on storage.objects;
drop policy if exists driver_documents_storage_operator_select on storage.objects;
drop policy if exists driver_documents_storage_operator_write on storage.objects;
create policy driver_documents_storage_operator_select on storage.objects
  for select to authenticated
  using (bucket_id = 'driver-documents' and public.is_operator_reader());
create policy driver_documents_storage_operator_write on storage.objects
  for all to authenticated
  using (bucket_id = 'driver-documents' and public.is_operator_writer())
  with check (bucket_id = 'driver-documents' and public.is_operator_writer());

-- ---------------------------------------------------------------------------
-- 3) Fare schedules (fix_operator_rbac_rls_patch.sql)
-- ---------------------------------------------------------------------------
drop policy if exists "fare_schedules_operator_insert" on public.fare_schedules;
drop policy if exists "fare_schedules_operator_update" on public.fare_schedules;
drop policy if exists "fare_schedules_operator_delete" on public.fare_schedules;
drop policy if exists fare_schedules_operator_select on public.fare_schedules;
create policy fare_schedules_operator_select on public.fare_schedules
  for select to authenticated using (public.is_operator_reader());
create policy "fare_schedules_operator_insert" on public.fare_schedules
  for insert to authenticated with check (public.is_operator_writer());
create policy "fare_schedules_operator_update" on public.fare_schedules
  for update to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());
create policy "fare_schedules_operator_delete" on public.fare_schedules
  for delete to authenticated using (public.is_operator_writer());

-- ---------------------------------------------------------------------------
-- 4) Fleet (fix_fleet_management.sql)
-- ---------------------------------------------------------------------------
drop policy if exists vehicle_assignments_operator_all on public.vehicle_assignments;
drop policy if exists vehicle_assignments_operator_select on public.vehicle_assignments;
drop policy if exists vehicle_assignments_operator_write on public.vehicle_assignments;
create policy vehicle_assignments_operator_select on public.vehicle_assignments
  for select to authenticated using (public.is_operator_reader());
create policy vehicle_assignments_operator_write on public.vehicle_assignments
  for all to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

drop policy if exists vehicle_maintenance_operator_all on public.vehicle_maintenance_logs;
drop policy if exists vehicle_maintenance_operator_select on public.vehicle_maintenance_logs;
drop policy if exists vehicle_maintenance_operator_write on public.vehicle_maintenance_logs;
create policy vehicle_maintenance_operator_select on public.vehicle_maintenance_logs
  for select to authenticated using (public.is_operator_reader());
create policy vehicle_maintenance_operator_write on public.vehicle_maintenance_logs
  for all to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

-- ---------------------------------------------------------------------------
-- 5) Payroll (fix_payroll.sql)
-- ---------------------------------------------------------------------------
drop policy if exists payroll_config_operator_all on public.payroll_deduction_configs;
drop policy if exists payroll_config_operator_select on public.payroll_deduction_configs;
drop policy if exists payroll_config_operator_write on public.payroll_deduction_configs;
create policy payroll_config_operator_select on public.payroll_deduction_configs
  for select to authenticated using (public.is_operator_reader());
create policy payroll_config_operator_write on public.payroll_deduction_configs
  for all to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

drop policy if exists cash_advances_operator_all on public.cash_advances;
drop policy if exists cash_advances_operator_select on public.cash_advances;
drop policy if exists cash_advances_operator_write on public.cash_advances;
create policy cash_advances_operator_select on public.cash_advances
  for select to authenticated using (public.is_operator_reader());
create policy cash_advances_operator_write on public.cash_advances
  for all to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

drop policy if exists payroll_records_operator_all on public.payroll_records;
drop policy if exists payroll_records_operator_select on public.payroll_records;
drop policy if exists payroll_records_operator_write on public.payroll_records;
create policy payroll_records_operator_select on public.payroll_records
  for select to authenticated using (public.is_operator_reader());
create policy payroll_records_operator_write on public.payroll_records
  for all to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

-- ---------------------------------------------------------------------------
-- 6) Driver training (fix_driver_training.sql) — operator write split
-- ---------------------------------------------------------------------------
drop policy if exists driver_training_operator_all on public.driver_training;
drop policy if exists driver_training_operator_select on public.driver_training;
drop policy if exists driver_training_operator_write on public.driver_training;
create policy driver_training_operator_select on public.driver_training
  for select to authenticated using (public.is_operator_reader());
create policy driver_training_operator_write on public.driver_training
  for all to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

notify pgrst, 'reload schema';
