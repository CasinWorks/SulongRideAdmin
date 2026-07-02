-- Carmona pilot: fare_config, driver approval, operators admin, FCM tokens.
--
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- (NOT Logs → Advanced filtering)
--
-- Tables are created before any policy that references them.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- 1) operators — must exist before fare_config / drivers admin policies
-- ---------------------------------------------------------------------------
create table if not exists public.operators (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null default '',
  full_name text not null default '',
  created_at timestamptz not null default now()
);

alter table public.operators enable row level security;

-- ---------------------------------------------------------------------------
-- 2) fare_config — flat ₱40 Carmona pilot
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 3) Driver approval status + FCM token columns
-- ---------------------------------------------------------------------------
alter table public.drivers
  add column if not exists approval_status text not null default 'pending';

alter table public.drivers
  drop constraint if exists drivers_approval_status_check;

alter table public.drivers
  add constraint drivers_approval_status_check
  check (approval_status in ('pending', 'approved', 'rejected'));

alter table public.users add column if not exists fcm_token text;
alter table public.drivers add column if not exists fcm_token text;

-- ---------------------------------------------------------------------------
-- 4) Seed active ₱40 flat fare row
-- ---------------------------------------------------------------------------
update public.fare_config set is_active = false where is_active = true;

insert into public.fare_config (base_fare, per_km_rate, minimum_fare, currency, is_active)
values (40.00, 0.00, 40.00, 'PHP', true);

-- ---------------------------------------------------------------------------
-- 5) RLS policies (operators table must already exist — see section 1)
-- ---------------------------------------------------------------------------

-- fare_config
drop policy if exists "fare_config_select_authenticated" on public.fare_config;
create policy "fare_config_select_authenticated"
  on public.fare_config for select to authenticated
  using (true);

drop policy if exists "fare_config_admin_update" on public.fare_config;
create policy "fare_config_admin_update"
  on public.fare_config for update to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()))
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));

drop policy if exists "fare_config_admin_insert" on public.fare_config;
create policy "fare_config_admin_insert"
  on public.fare_config for insert to authenticated
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));

grant select on table public.fare_config to authenticated;
grant insert, update on table public.fare_config to authenticated;

-- operators
drop policy if exists "operators_select_self" on public.operators;
create policy "operators_select_self"
  on public.operators for select to authenticated
  using (auth.uid() = id);

grant select on table public.operators to authenticated;

-- drivers (admin approval queue)
drop policy if exists "drivers_select_admin" on public.drivers;
create policy "drivers_select_admin"
  on public.drivers for select to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()));

drop policy if exists "drivers_update_admin" on public.drivers;
create policy "drivers_update_admin"
  on public.drivers for update to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()))
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));

-- ---------------------------------------------------------------------------
-- 6) Manual steps after this script
-- ---------------------------------------------------------------------------
-- Auth → add operator user, then:
-- insert into public.operators (id, email, full_name)
-- values ('YOUR_AUTH_USER_UUID', 'ops@example.com', 'Operator Name');
--
-- Approve test drivers:
-- update public.drivers set approval_status = 'approved' where email = 'driver@example.com';
--
-- Dashboard → Database → Replication → enable Realtime: trips, drivers, messages

notify pgrst, 'reload schema';
