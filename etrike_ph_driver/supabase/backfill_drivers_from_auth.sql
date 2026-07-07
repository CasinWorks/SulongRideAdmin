-- Run in Supabase → SQL Editor (optional)
-- Fixes: driver app login / trips FK when auth.users exists with role=driver
-- but public.drivers does not (e.g. email confirm was on during Register).
-- Safe to re-run; skips rows that already exist.

insert into public.drivers (
  id,
  full_name,
  email,
  phone,
  trike_plate_number,
  trike_model,
  is_online,
  is_available
)
select
  u.id,
  coalesce(
    nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
    'Driver'
  ) as full_name,
  coalesce(
    nullif(trim(u.email), ''),
    u.id::text || '@placeholder.local'
  ) as email,
  nullif(trim(u.raw_user_meta_data ->> 'phone'), '') as phone,
  nullif(trim(u.raw_user_meta_data ->> 'trike_plate_number'), '') as trike_plate_number,
  nullif(trim(u.raw_user_meta_data ->> 'trike_model'), '') as trike_model,
  false as is_online,
  false as is_available
from auth.users u
where coalesce(u.raw_user_meta_data ->> 'role', '') = 'driver'
  and not exists (
    select 1 from public.drivers d where d.id = u.id
  )
on conflict (id) do nothing;

notify pgrst, 'reload schema';
