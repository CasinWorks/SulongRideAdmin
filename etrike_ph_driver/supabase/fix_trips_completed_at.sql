-- Run in Supabase → SQL Editor (same project as keys.dart).
-- Fixes PGRST204: Could not find the 'completed_at' column of 'trips'.

alter table public.trips
  add column if not exists completed_at timestamptz;

notify pgrst, 'reload schema';

select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'trips'
order by ordinal_position;
