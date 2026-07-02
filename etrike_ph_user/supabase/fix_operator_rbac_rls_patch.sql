-- Patch after fix_operator_rbac.sql + fix_fare_schedules.sql + fix_audit_logs.sql
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
--
-- Fixes:
-- 1) audit_logs.actor_role check rejected super_admin/admin/viewer on insert (HTTP 400)
-- 2) fare_schedules policies still allowed pending operators after RBAC migration
-- 3) Missing table grants for authenticated role on admin tables

-- ---------------------------------------------------------------------------
-- 1) audit_logs — allow operator RBAC roles in actor_role column
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
      'viewer'
    )
  );

drop policy if exists "audit_insert_own" on public.audit_logs;
create policy "audit_insert_own"
  on public.audit_logs for insert to authenticated
  with check (
    actor_id = auth.uid()
    and public.is_approved_operator()
  );

drop policy if exists "audit_select_admin" on public.audit_logs;
create policy "audit_select_admin"
  on public.audit_logs for select to authenticated
  using (public.is_approved_operator());

grant select, insert on table public.audit_logs to authenticated;

-- ---------------------------------------------------------------------------
-- 2) fare_schedules — approved operators only (match other admin tables)
-- ---------------------------------------------------------------------------
drop policy if exists "fare_schedules_operator_insert" on public.fare_schedules;
create policy "fare_schedules_operator_insert"
  on public.fare_schedules for insert to authenticated
  with check (public.is_approved_operator());

drop policy if exists "fare_schedules_operator_update" on public.fare_schedules;
create policy "fare_schedules_operator_update"
  on public.fare_schedules for update to authenticated
  using (public.is_approved_operator())
  with check (public.is_approved_operator());

drop policy if exists "fare_schedules_operator_delete" on public.fare_schedules;
create policy "fare_schedules_operator_delete"
  on public.fare_schedules for delete to authenticated
  using (public.is_approved_operator());

-- ---------------------------------------------------------------------------
-- 3) drivers — ensure authenticated can query (RLS still applies)
-- ---------------------------------------------------------------------------
grant select, update on table public.drivers to authenticated;

notify pgrst, 'reload schema';
