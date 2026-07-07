-- Fare schedules + effective_fare_config view (SECURITY INVOKER — fixes Supabase linter CRITICAL)
--
-- Run in: Supabase Dashboard → SQL Editor
--
-- Fixes: "Security Definer View" on public.effective_fare_config
-- The view now runs as the querying user (rider/driver/operator) and respects RLS.
-- Riders/drivers read active fare via narrow SELECT policies on fare_config + fare_schedules.

-- ---------------------------------------------------------------------------
-- 1) fare_schedules table (idempotent)
-- ---------------------------------------------------------------------------
create table if not exists public.fare_schedules (
  id uuid primary key default gen_random_uuid(),
  label text not null default '',
  schedule_type text not null default 'discount'
    check (schedule_type in ('discount', 'override')),
  base_fare numeric not null default 40.00,
  per_km_rate numeric not null default 0.00,
  minimum_fare numeric not null default 40.00,
  currency text not null default 'PHP',
  starts_at timestamptz not null,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.fare_schedules enable row level security;

grant select, insert, update, delete on table public.fare_schedules to authenticated;

-- ---------------------------------------------------------------------------
-- 2) RLS — apps read only the fare row(s) needed for pricing
-- ---------------------------------------------------------------------------

-- Active default fare (rider/driver apps). Operators also match is_operator_reader().
drop policy if exists "fare_config_read_active" on public.fare_config;
create policy "fare_config_read_active"
  on public.fare_config for select to authenticated
  using (is_active = true);

-- Currently effective scheduled fare window only (no future/past schedule list for apps).
drop policy if exists "fare_schedules_select_effective" on public.fare_schedules;
create policy "fare_schedules_select_effective"
  on public.fare_schedules for select to authenticated
  using (
    is_active = true
    and starts_at <= timezone('utc', now())
    and (ends_at is null or ends_at >= timezone('utc', now()))
  );

-- Operator policies (idempotent — match fix_operator_rbac_viewer.sql)
drop policy if exists fare_schedules_operator_select on public.fare_schedules;
create policy fare_schedules_operator_select on public.fare_schedules
  for select to authenticated
  using (public.is_operator_reader());

drop policy if exists "fare_schedules_operator_insert" on public.fare_schedules;
create policy "fare_schedules_operator_insert" on public.fare_schedules
  for insert to authenticated
  with check (public.is_operator_writer());

drop policy if exists "fare_schedules_operator_update" on public.fare_schedules;
create policy "fare_schedules_operator_update" on public.fare_schedules
  for update to authenticated
  using (public.is_operator_writer())
  with check (public.is_operator_writer());

drop policy if exists "fare_schedules_operator_delete" on public.fare_schedules;
create policy "fare_schedules_operator_delete" on public.fare_schedules
  for delete to authenticated
  using (public.is_operator_writer());

-- ---------------------------------------------------------------------------
-- 3) effective_fare_config — SECURITY INVOKER (not DEFINER)
-- ---------------------------------------------------------------------------
drop view if exists public.effective_fare_config;

create view public.effective_fare_config
with (security_invoker = true)
as
with default_fare as (
  select
    fc.id,
    fc.base_fare,
    fc.per_km_rate,
    fc.minimum_fare,
    fc.currency,
    fc.is_active,
    fc.updated_at
  from public.fare_config fc
  where fc.is_active = true
  order by fc.updated_at desc nulls last
  limit 1
),
active_schedule as (
  select
    fs.id as schedule_id,
    fs.label as schedule_label,
    fs.base_fare,
    fs.per_km_rate,
    fs.minimum_fare,
    fs.currency,
    fs.updated_at,
    fs.schedule_type
  from public.fare_schedules fs
  where fs.is_active = true
    and fs.starts_at <= timezone('utc', now())
    and (fs.ends_at is null or fs.ends_at >= timezone('utc', now()))
  order by
    case fs.schedule_type
      when 'override' then 0
      when 'discount' then 1
      else 2
    end,
    fs.starts_at desc
  limit 1
)
select
  case when s.schedule_id is not null then s.schedule_id else d.id end as id,
  coalesce(s.base_fare, d.base_fare) as base_fare,
  coalesce(s.per_km_rate, d.per_km_rate) as per_km_rate,
  coalesce(s.minimum_fare, d.minimum_fare) as minimum_fare,
  coalesce(s.currency, d.currency, 'PHP') as currency,
  coalesce(d.is_active, true) as is_active,
  coalesce(s.updated_at, d.updated_at) as updated_at,
  case
    when s.schedule_id is not null then 'schedule'::text
    else 'default'::text
  end as fare_source,
  s.schedule_id,
  s.schedule_label
from default_fare d
left join active_schedule s on true;

grant select on public.effective_fare_config to authenticated;

comment on view public.effective_fare_config is
  'Resolved fare at now(): active schedule in window, else default fare_config. security_invoker=true.';

notify pgrst, 'reload schema';
