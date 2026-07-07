-- Run ALL of this in Supabase → SQL Editor (same project as keys.dart supabaseUrl).

-- 1) Add column (safe if already added)
alter table public.trips
  add column if not exists distance_km numeric;

-- 2) If your table used `distance` instead, copy into distance_km once:
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'trips' and column_name = 'distance'
  ) then
    execute 'update public.trips set distance_km = distance where distance_km is null and distance is not null';
  end if;
end $$;

-- 3) REQUIRED: refresh PostgREST schema cache (fixes PGRST204 after ALTER)
notify pgrst, 'reload schema';

-- 4) Verify column is visible (should list distance_km)
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'trips'
order by ordinal_position;
