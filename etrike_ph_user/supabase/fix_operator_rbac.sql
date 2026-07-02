-- Operator RBAC + approval gate for Sulong Ride Admin (etrike_ph_admin_web).
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
--
-- Adds approval_status + role to operators, bootstraps super admin,
-- and tightens RLS so only approved operators can access admin data.

-- ---------------------------------------------------------------------------
-- 1) Extend operators table
-- ---------------------------------------------------------------------------
alter table public.operators
  add column if not exists approval_status text not null default 'pending';

alter table public.operators
  add column if not exists role text not null default 'admin';

alter table public.operators
  add column if not exists approved_by uuid references auth.users (id) on delete set null;

alter table public.operators
  add column if not exists approved_at timestamptz;

alter table public.operators
  drop constraint if exists operators_approval_status_check;

alter table public.operators
  add constraint operators_approval_status_check
  check (approval_status in ('pending', 'approved', 'revoked'));

alter table public.operators
  drop constraint if exists operators_role_check;

alter table public.operators
  add constraint operators_role_check
  check (role in ('super_admin', 'admin', 'viewer'));

-- Existing rows were created manually — treat them as approved admins.
update public.operators
set
  approval_status = 'approved',
  role = coalesce(nullif(role, ''), 'admin'),
  approved_at = coalesce(approved_at, created_at, now())
where approval_status = 'pending'
  and role in ('admin', 'viewer', 'super_admin');

-- Bootstrap super admin (must exist in auth.users first).
insert into public.operators (id, email, full_name, approval_status, role, approved_at)
select
  id,
  email,
  coalesce(raw_user_meta_data->>'full_name', 'Christian Joshua Casin'),
  'approved',
  'super_admin',
  now()
from auth.users
where email = 'christianjoshuacasin@gmail.com'
on conflict (id) do update
  set
    email = excluded.email,
    approval_status = 'approved',
    role = 'super_admin',
    approved_at = coalesce(public.operators.approved_at, now());

-- ---------------------------------------------------------------------------
-- 2) Helper functions for RLS
-- ---------------------------------------------------------------------------
create or replace function public.is_approved_operator()
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
  );
$$;

create or replace function public.is_super_admin_operator()
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
      and o.role = 'super_admin'
  );
$$;

grant execute on function public.is_approved_operator() to authenticated;
grant execute on function public.is_super_admin_operator() to authenticated;

-- ---------------------------------------------------------------------------
-- 3) operators RLS
-- ---------------------------------------------------------------------------
drop policy if exists "operators_select_self" on public.operators;
create policy "operators_select_self"
  on public.operators for select to authenticated
  using (auth.uid() = id or public.is_super_admin_operator());

drop policy if exists "operators_insert_self_pending" on public.operators;
create policy "operators_insert_self_pending"
  on public.operators for insert to authenticated
  with check (
    auth.uid() = id
    and approval_status = 'pending'
    and role in ('admin', 'viewer')
  );

drop policy if exists "operators_update_super_admin" on public.operators;
create policy "operators_update_super_admin"
  on public.operators for update to authenticated
  using (public.is_super_admin_operator())
  with check (public.is_super_admin_operator());

grant select, insert, update on table public.operators to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Replace operator checks on admin tables (approved only)
-- ---------------------------------------------------------------------------

-- fare_config
drop policy if exists "fare_config_admin_update" on public.fare_config;
create policy "fare_config_admin_update"
  on public.fare_config for update to authenticated
  using (public.is_approved_operator())
  with check (public.is_approved_operator());

drop policy if exists "fare_config_admin_insert" on public.fare_config;
create policy "fare_config_admin_insert"
  on public.fare_config for insert to authenticated
  with check (public.is_approved_operator());

-- drivers
drop policy if exists "drivers_select_admin" on public.drivers;
create policy "drivers_select_admin"
  on public.drivers for select to authenticated
  using (public.is_approved_operator());

drop policy if exists "drivers_update_admin" on public.drivers;
create policy "drivers_update_admin"
  on public.drivers for update to authenticated
  using (public.is_approved_operator())
  with check (public.is_approved_operator());

-- trips
drop policy if exists "trips_select_admin" on public.trips;
create policy "trips_select_admin"
  on public.trips for select to authenticated
  using (public.is_approved_operator());

drop policy if exists "trips_update_admin" on public.trips;
create policy "trips_update_admin"
  on public.trips for update to authenticated
  using (public.is_approved_operator())
  with check (public.is_approved_operator());

-- audit_logs
drop policy if exists "audit_select_admin" on public.audit_logs;
create policy "audit_select_admin"
  on public.audit_logs for select to authenticated
  using (public.is_approved_operator());

-- driver HR (attendance + leave)
drop policy if exists "attendance_select_admin" on public.driver_attendance;
create policy "attendance_select_admin"
  on public.driver_attendance for select to authenticated
  using (public.is_approved_operator());

drop policy if exists "attendance_update_admin" on public.driver_attendance;
create policy "attendance_update_admin"
  on public.driver_attendance for update to authenticated
  using (public.is_approved_operator());

drop policy if exists "leave_select_admin" on public.leave_requests;
create policy "leave_select_admin"
  on public.leave_requests for select to authenticated
  using (public.is_approved_operator());

drop policy if exists "leave_update_admin" on public.leave_requests;
create policy "leave_update_admin"
  on public.leave_requests for update to authenticated
  using (public.is_approved_operator());

-- onboarding tables (if present)
drop policy if exists vehicles_operator_all on public.vehicles;
create policy vehicles_operator_all on public.vehicles
  for all to authenticated
  using (public.is_approved_operator())
  with check (public.is_approved_operator());

drop policy if exists driver_documents_operator_all on public.driver_documents;
create policy driver_documents_operator_all on public.driver_documents
  for all to authenticated
  using (public.is_approved_operator())
  with check (public.is_approved_operator());

drop policy if exists hiring_pipeline_operator_all on public.driver_hiring_pipeline;
create policy hiring_pipeline_operator_all on public.driver_hiring_pipeline
  for all to authenticated
  using (public.is_approved_operator())
  with check (public.is_approved_operator());

drop policy if exists onboarding_timeline_operator_all on public.onboarding_timeline;
create policy onboarding_timeline_operator_all on public.onboarding_timeline
  for all to authenticated
  using (public.is_approved_operator())
  with check (public.is_approved_operator());

drop policy if exists registration_drafts_operator_all on public.driver_registration_drafts;
create policy registration_drafts_operator_all on public.driver_registration_drafts
  for all to authenticated
  using (public.is_approved_operator())
  with check (public.is_approved_operator());

-- storage (driver documents bucket)
drop policy if exists driver_documents_storage_operator on storage.objects;
create policy driver_documents_storage_operator on storage.objects
  for all to authenticated
  using (
    bucket_id = 'driver-documents'
    and public.is_approved_operator()
  )
  with check (
    bucket_id = 'driver-documents'
    and public.is_approved_operator()
  );

notify pgrst, 'reload schema';
