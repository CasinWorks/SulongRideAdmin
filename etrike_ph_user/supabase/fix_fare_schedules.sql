-- Scheduled fare overrides (promotions / temporary increases).
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
--
-- Default fare stays in fare_config (₱40 flat). Active schedules override at read time;
-- when a schedule's ends_at passes, effective_fare_config falls back to fare_config automatically.
--
-- Prerequisites: fix_carmona_pilot.sql (fare_config + operators)

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- 1) fare_schedules — time-bounded fare overrides
-- ---------------------------------------------------------------------------
create table if not exists public.fare_schedules (
  id uuid primary key default gen_random_uuid(),
  label text not null default '',
  base_fare numeric not null,
  per_km_rate numeric not null default 0.00,
  minimum_fare numeric not null,
  currency text not null default 'PHP',
  schedule_type text not null default 'discount'
    check (schedule_type in ('discount', 'override')),
  starts_at timestamptz not null,
  ends_at timestamptz, -- null = indefinite until manually deactivated
  is_active boolean not null default true,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists fare_schedules_window_idx
  on public.fare_schedules (starts_at, ends_at)
  where is_active = true;

alter table public.fare_schedules enable row level security;

-- Riders/drivers read schedules indirectly via effective_fare_config view.
drop policy if exists "fare_schedules_select_authenticated" on public.fare_schedules;
create policy "fare_schedules_select_authenticated"
  on public.fare_schedules for select to authenticated
  using (true);

drop policy if exists "fare_schedules_operator_insert" on public.fare_schedules;
create policy "fare_schedules_operator_insert"
  on public.fare_schedules for insert to authenticated
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));

drop policy if exists "fare_schedules_operator_update" on public.fare_schedules;
create policy "fare_schedules_operator_update"
  on public.fare_schedules for update to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()))
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));

drop policy if exists "fare_schedules_operator_delete" on public.fare_schedules;
create policy "fare_schedules_operator_delete"
  on public.fare_schedules for delete to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()));

grant select on table public.fare_schedules to authenticated;
grant insert, update, delete on table public.fare_schedules to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Ensure default ₱40 row exists in fare_config
-- ---------------------------------------------------------------------------
update public.fare_config
set is_active = false
where is_active = true
  and not exists (
    select 1 from public.fare_config fc where fc.is_active = true
  );

insert into public.fare_config (base_fare, per_km_rate, minimum_fare, currency, is_active)
select 40.00, 0.00, 40.00, 'PHP', true
where not exists (
  select 1 from public.fare_config where is_active = true
);

-- ---------------------------------------------------------------------------
-- 3) Resolve effective fare at a point in time (for RPC / server use)
-- ---------------------------------------------------------------------------
create or replace function public.get_effective_fare(at_time timestamptz default now())
returns table (
  id uuid,
  base_fare numeric,
  per_km_rate numeric,
  minimum_fare numeric,
  currency text,
  is_active boolean,
  updated_at timestamptz,
  fare_source text,
  schedule_id uuid,
  schedule_label text
)
language sql
stable
as $$
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
    order by fc.updated_at desc
    limit 1
  ),
  active_schedule as (
    select
      fs.id,
      fs.label,
      fs.base_fare,
      fs.per_km_rate,
      fs.minimum_fare,
      fs.currency,
      fs.updated_at
    from public.fare_schedules fs
    where fs.is_active = true
      and fs.starts_at <= at_time
      and (fs.ends_at is null or fs.ends_at >= at_time)
    order by fs.starts_at desc
    limit 1
  )
  select
    coalesce(s.id, d.id, gen_random_uuid()) as id,
    coalesce(s.base_fare, d.base_fare, 40::numeric) as base_fare,
    coalesce(s.per_km_rate, d.per_km_rate, 0::numeric) as per_km_rate,
    coalesce(s.minimum_fare, d.minimum_fare, 40::numeric) as minimum_fare,
    coalesce(s.currency, d.currency, 'PHP') as currency,
    true as is_active,
    coalesce(s.updated_at, d.updated_at, at_time) as updated_at,
    case when s.id is not null then 'schedule' else 'default' end as fare_source,
    s.id as schedule_id,
    s.label as schedule_label
  from (select 1) anchor
  left join default_fare d on true
  left join active_schedule s on true;
$$;

grant execute on function public.get_effective_fare(timestamptz) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) View for mobile/admin clients (same shape as fare_config + metadata)
-- ---------------------------------------------------------------------------
create or replace view public.effective_fare_config as
select
  id,
  base_fare,
  per_km_rate,
  minimum_fare,
  currency,
  is_active,
  updated_at,
  fare_source,
  schedule_id,
  schedule_label
from public.get_effective_fare(now());

grant select on public.effective_fare_config to authenticated;

notify pgrst, 'reload schema';
