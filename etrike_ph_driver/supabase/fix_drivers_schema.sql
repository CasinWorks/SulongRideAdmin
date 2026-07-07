-- Run ALL of this in Supabase → SQL Editor (same project as keys.dart supabaseUrl).
-- Fixes: PostgrestException PGRST204 — column not in schema cache (e.g. is_online).

-- ---------------------------------------------------------------------------
-- 1) Ensure `drivers` exists (minimal); then add every column the apps use
-- ---------------------------------------------------------------------------
create table if not exists public.drivers (
  id uuid primary key references auth.users (id) on delete cascade
);

alter table public.drivers add column if not exists full_name text not null default '';
alter table public.drivers add column if not exists email text not null default '';
alter table public.drivers add column if not exists phone text;
alter table public.drivers add column if not exists profile_photo_url text;
alter table public.drivers add column if not exists trike_plate_number text;
alter table public.drivers add column if not exists trike_model text;
alter table public.drivers add column if not exists is_available boolean not null default false;
alter table public.drivers add column if not exists is_online boolean not null default false;
alter table public.drivers add column if not exists current_lat double precision;
alter table public.drivers add column if not exists current_lng double precision;
alter table public.drivers add column if not exists fcm_token text;
alter table public.drivers add column if not exists created_at timestamptz not null default now();
alter table public.drivers add column if not exists updated_at timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- 2) REQUIRED: refresh PostgREST schema cache (fixes PGRST204 after ALTER)
-- ---------------------------------------------------------------------------
notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------------
-- 3) Verify columns (should include is_online, is_available, current_lat/lng)
-- ---------------------------------------------------------------------------
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'drivers'
order by ordinal_position;
