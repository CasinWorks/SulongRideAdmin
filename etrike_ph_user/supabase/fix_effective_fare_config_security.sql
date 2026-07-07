-- Quick fix: Supabase CRITICAL "Security Definer View" on effective_fare_config
--
-- Run this if you only need to clear the linter alert without re-running the full
-- fix_fare_schedules.sql. Requires fare_schedules table + is_operator_reader() already deployed.
--
-- Same as the view + RLS section in fix_fare_schedules.sql.

drop policy if exists "fare_config_read_active" on public.fare_config;
create policy "fare_config_read_active"
  on public.fare_config for select to authenticated
  using (is_active = true);

drop policy if exists "fare_schedules_select_effective" on public.fare_schedules;
create policy "fare_schedules_select_effective"
  on public.fare_schedules for select to authenticated
  using (
    is_active = true
    and starts_at <= timezone('utc', now())
    and (ends_at is null or ends_at >= timezone('utc', now()))
  );

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

notify pgrst, 'reload schema';
