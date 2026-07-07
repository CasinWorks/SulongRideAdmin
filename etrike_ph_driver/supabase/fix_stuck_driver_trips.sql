-- Run in Supabase → SQL Editor when a driver cannot receive new bookings
-- because an old trip is stuck in accepted/ongoing.

-- See stuck trips for a driver (replace with your driver auth user id):
-- select id, status, pickup_address, created_at
-- from public.trips
-- where driver_id = 'YOUR-DRIVER-UUID'
--   and status in ('accepted', 'ongoing')
-- order by created_at desc;

-- Mark stuck trips as completed (safe if you know they are finished):
update public.trips
set status = 'completed',
    completed_at = coalesce(completed_at, now())
where status in ('accepted', 'ongoing')
  and driver_id is not null
  and created_at < now() - interval '2 hours';

notify pgrst, 'reload schema';
