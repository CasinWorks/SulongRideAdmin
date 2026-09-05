-- Auto time-out: close open driver_attendance older than 24 hours and take
-- those drivers offline. The driver app also enforces this on launch / Online.
-- Run in Supabase SQL Editor. Optional: schedule via pg_cron every 15 minutes.

create or replace function public.close_stale_driver_attendance()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer := 0;
begin
  with closed as (
    update public.driver_attendance
    set
      clock_out = now(),
      notes = case
        when notes is null or btrim(notes) = '' then 'auto_timeout_24h'
        else notes
      end
    where clock_out is null
      and clock_in <= now() - interval '24 hours'
    returning driver_id
  )
  update public.drivers d
  set is_online = false,
      is_available = false
  from closed
  where d.id = closed.driver_id;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.close_stale_driver_attendance() from public;
grant execute on function public.close_stale_driver_attendance() to authenticated;
grant execute on function public.close_stale_driver_attendance() to service_role;

-- Optional: uncomment if pg_cron is enabled on the project.
-- select cron.schedule(
--   'close-stale-driver-attendance',
--   '*/15 * * * *',
--   $$select public.close_stale_driver_attendance()$$
-- );

notify pgrst, 'reload schema';
