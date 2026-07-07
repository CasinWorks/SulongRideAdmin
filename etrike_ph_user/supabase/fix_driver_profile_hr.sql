-- Driver HR profile fields for admin roster & directory.
-- Run after fix_driver_hr.sql in Supabase SQL Editor.

alter table public.drivers
  add column if not exists employment_type text not null default 'contractual',
  add column if not exists station text not null default 'Carmona Central',
  add column if not exists shift_schedule text not null default 'Mon–Sat · 6:00 AM – 2:00 PM',
  add column if not exists emergency_contact text not null default '',
  add column if not exists start_date date;

alter table public.drivers
  drop constraint if exists drivers_employment_type_check;

alter table public.drivers
  add constraint drivers_employment_type_check
  check (employment_type in ('contractual', 'permanent'));

-- Backfill start_date from account created_at when missing
update public.drivers
set start_date = (created_at at time zone 'Asia/Manila')::date
where start_date is null and created_at is not null;

notify pgrst, 'reload schema';
