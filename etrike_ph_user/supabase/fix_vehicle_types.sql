-- Vehicle types catalog (rider app vehicle options) + Admin Web CRUD
--
-- Run in: Supabase Dashboard → SQL Editor
--
-- Creates `public.vehicle_types` and RLS policies:
-- - Mobile apps can SELECT only active vehicle types.
-- - Approved operators can SELECT all; writers can INSERT/UPDATE/DELETE.
--
-- Requires operator RBAC helpers from `fix_operator_rbac.sql` + role scripts:
-- - public.is_operator_reader()
-- - public.is_operator_writer()

create table if not exists public.vehicle_types (
  id text primary key, -- e.g. bike, economy, premium
  name text not null,
  description text not null default '',
  icon text not null default '🛺',
  eta_minutes integer not null default 3,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null
);

alter table public.vehicle_types enable row level security;

grant select, insert, update, delete on table public.vehicle_types to authenticated;

-- Apps: only active entries (what riders see).
drop policy if exists "vehicle_types_select_active" on public.vehicle_types;
create policy "vehicle_types_select_active"
  on public.vehicle_types for select to authenticated
  using (is_active = true);

-- Operators: read all (including disabled, so they can re-enable).
drop policy if exists "vehicle_types_operator_select" on public.vehicle_types;
create policy "vehicle_types_operator_select"
  on public.vehicle_types for select to authenticated
  using (public.is_operator_reader());

-- Operators (writers): full CRUD.
drop policy if exists "vehicle_types_operator_insert" on public.vehicle_types;
create policy "vehicle_types_operator_insert"
  on public.vehicle_types for insert to authenticated
  with check (public.is_operator_writer());

drop policy if exists "vehicle_types_operator_update" on public.vehicle_types;
create policy "vehicle_types_operator_update"
  on public.vehicle_types for update to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

drop policy if exists "vehicle_types_operator_delete" on public.vehicle_types;
create policy "vehicle_types_operator_delete"
  on public.vehicle_types for delete to authenticated
  using (public.is_operator_writer());

-- Seed defaults (idempotent)
insert into public.vehicle_types (id, name, description, icon, eta_minutes, sort_order, is_active)
values
  ('bike', 'EcoTrike Commuter', 'Standard electric tricycle with comfortable seating', '🛺', 2, 10, true),
  ('economy', 'EcoTrike Solo', 'Agile, single-passenger electric micro-trike', '🛺', 3, 20, true),
  ('premium', 'EcoTrike Premium', 'Deluxe tricycle with cushion seats and solar canopy', '🛺⚡', 4, 30, true),
  ('xl', 'EcoTrike Sidecar XL', 'Large capacity electric sidecar for family or luggage', '🛺', 5, 40, true),
  ('taxi', 'EcoRickshaw Express', 'Multi-seater covered electric passenger shuttle', '🛺⚡', 4, 50, true)
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  icon = excluded.icon,
  eta_minutes = excluded.eta_minutes,
  sort_order = excluded.sort_order;

notify pgrst, 'reload schema';

