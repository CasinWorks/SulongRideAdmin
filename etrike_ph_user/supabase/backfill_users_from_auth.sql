-- Run in Supabase → SQL Editor (optional)
-- Fixes: trips_rider_id_fkey (23503) when auth.users exists but public.users does not.
-- Safe to re-run; skips rows that already exist.

insert into public.users (id, full_name, email)
select
  u.id,
  coalesce(
    nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
    'Rider'
  ) as full_name,
  coalesce(
    nullif(trim(u.email), ''),
    u.id::text || '@placeholder.local'
  ) as email
from auth.users u
where not exists (
  select 1 from public.users p where p.id = u.id
)
on conflict (id) do nothing;

notify pgrst, 'reload schema';
