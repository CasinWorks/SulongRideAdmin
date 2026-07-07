-- Structured shift fields for per-driver schedule setup (admin web).
-- Run after fix_driver_profile_hr.sql.

alter table public.drivers
  add column if not exists shift_days integer[] not null default '{1,2,3,4,5,6}',
  add column if not exists shift_start time not null default '06:00:00',
  add column if not exists shift_end time not null default '14:00:00';

-- Backfill display text from structured fields where still default
update public.drivers
set shift_schedule = 'Mon–Sat · 6:00 AM – 2:00 PM'
where shift_schedule is null or shift_schedule = '';

notify pgrst, 'reload schema';
