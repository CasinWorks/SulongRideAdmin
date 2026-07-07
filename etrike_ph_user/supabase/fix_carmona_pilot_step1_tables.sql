-- Step 1 of 3 — tables + columns (no RLS policies yet).
-- Run in: Supabase Dashboard → SQL Editor → New query → Run

create extension if not exists "pgcrypto";

create table if not exists public.fare_config (
  id uuid primary key default gen_random_uuid(),
  base_fare numeric not null default 40.00,
  per_km_rate numeric not null default 0.00,
  minimum_fare numeric not null default 40.00,
  currency text not null default 'PHP',
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.fare_config enable row level security;

create table if not exists public.operators (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null default '',
  full_name text not null default '',
  created_at timestamptz not null default now()
);

alter table public.operators enable row level security;

alter table public.drivers
  add column if not exists approval_status text not null default 'pending';

alter table public.drivers
  drop constraint if exists drivers_approval_status_check;

alter table public.drivers
  add constraint drivers_approval_status_check
  check (approval_status in ('pending', 'approved', 'rejected'));

alter table public.users add column if not exists fcm_token text;
alter table public.drivers add column if not exists fcm_token text;

update public.fare_config set is_active = false where is_active = true;

insert into public.fare_config (base_fare, per_km_rate, minimum_fare, currency, is_active)
values (40.00, 0.00, 40.00, 'PHP', true);

notify pgrst, 'reload schema';
