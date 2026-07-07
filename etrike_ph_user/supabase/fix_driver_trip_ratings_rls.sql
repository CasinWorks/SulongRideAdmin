-- Let drivers read passenger trip ratings logged in audit_logs (for stats UI).
-- Run after fix_audit_logs.sql and fix_trip_ratings.sql

drop policy if exists "audit_select_driver_trip_ratings" on public.audit_logs;
create policy "audit_select_driver_trip_ratings"
  on public.audit_logs for select to authenticated
  using (
    action = 'trip.rate'
    and entity_type = 'trips'
    and entity_id is not null
    and exists (
      select 1 from public.trips t
      where t.id::text = entity_id
        and t.driver_id = auth.uid()
    )
  );

notify pgrst, 'reload schema';
