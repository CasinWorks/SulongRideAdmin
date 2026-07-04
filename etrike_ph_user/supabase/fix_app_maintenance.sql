-- Sulong Ride — scheduled app maintenance (blocks driver + rider apps).
-- Admin/super_admin schedule via admin web; mobile apps read get_app_maintenance_status().
-- Run after fix_operator_rbac.sql

create table if not exists public.app_maintenance (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'scheduled'
    check (status in ('scheduled', 'active', 'ended', 'cancelled')),
  title text not null default 'Scheduled maintenance',
  message text not null default 'We are performing maintenance. Please try again later.',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  block_apps boolean not null default true,
  notify_users boolean not null default true,
  ended_early_at timestamptz,
  created_by uuid references auth.users (id),
  updated_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint app_maintenance_window_check check (ends_at > starts_at)
);

create index if not exists app_maintenance_window_idx
  on public.app_maintenance (starts_at desc, ends_at desc);

alter table public.app_maintenance enable row level security;

drop policy if exists app_maintenance_admin_all on public.app_maintenance;
create policy app_maintenance_admin_all on public.app_maintenance
  for all to authenticated
  using (public.is_admin_operator())
  with check (public.is_admin_operator());

grant select, insert, update, delete on public.app_maintenance to authenticated;

-- Effective status for mobile apps (anon + authenticated).
create or replace function public.get_app_maintenance_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  row public.app_maintenance;
  effective_end timestamptz;
  phase text := 'inactive';
begin
  select *
  into row
  from public.app_maintenance m
  where m.status in ('scheduled', 'active')
    and m.ended_early_at is null
    and now() < m.ends_at
  order by m.starts_at desc
  limit 1;

  if not found then
    return jsonb_build_object('phase', 'inactive');
  end if;

  effective_end := row.ends_at;

  if now() >= row.starts_at and now() < effective_end then
    phase := 'active';
  elsif row.notify_users and now() < row.starts_at then
    phase := 'scheduled';
  else
    return jsonb_build_object('phase', 'inactive');
  end if;

  return jsonb_build_object(
    'phase', phase,
    'id', row.id,
    'title', row.title,
    'message', row.message,
    'starts_at', row.starts_at,
    'ends_at', effective_end,
    'block_apps', row.block_apps,
    'notify_users', row.notify_users
  );
end;
$$;

grant execute on function public.get_app_maintenance_status() to anon, authenticated;

create or replace function public.admin_schedule_maintenance(
  p_title text,
  p_message text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_block_apps boolean default true,
  p_notify_users boolean default true
)
returns public.app_maintenance
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.app_maintenance;
begin
  if not public.is_admin_operator() then
    raise exception 'Only admin operators can schedule maintenance';
  end if;

  if p_ends_at <= p_starts_at then
    raise exception 'End time must be after start time';
  end if;

  if exists (
    select 1
    from public.app_maintenance m
    where m.status in ('scheduled', 'active')
      and m.ended_early_at is null
      and m.ends_at > now()
      and tstzrange(m.starts_at, m.ends_at, '[)') && tstzrange(p_starts_at, p_ends_at, '[)')
  ) then
    raise exception 'Another maintenance window overlaps this schedule';
  end if;

  insert into public.app_maintenance (
    status,
    title,
    message,
    starts_at,
    ends_at,
    block_apps,
    notify_users,
    created_by,
    updated_by
  )
  values (
    'scheduled',
    coalesce(nullif(trim(p_title), ''), 'Scheduled maintenance'),
    coalesce(nullif(trim(p_message), ''), 'We are performing maintenance. Please try again later.'),
    p_starts_at,
    p_ends_at,
    coalesce(p_block_apps, true),
    coalesce(p_notify_users, true),
    auth.uid(),
    auth.uid()
  )
  returning * into result;

  return result;
end;
$$;

grant execute on function public.admin_schedule_maintenance(text, text, timestamptz, timestamptz, boolean, boolean) to authenticated;

create or replace function public.admin_extend_maintenance(
  p_id uuid,
  p_new_ends_at timestamptz
)
returns public.app_maintenance
language plpgsql
security definer
set search_path = public
as $$
declare
  row public.app_maintenance;
begin
  if not public.is_admin_operator() then
    raise exception 'Only admin operators can extend maintenance';
  end if;

  select * into row from public.app_maintenance where id = p_id for update;
  if not found then
    raise exception 'Maintenance window not found';
  end if;

  if row.status not in ('scheduled', 'active') or row.ended_early_at is not null then
    raise exception 'Maintenance window is not open';
  end if;

  if p_new_ends_at <= row.starts_at then
    raise exception 'New end time must be after start time';
  end if;

  if p_new_ends_at <= now() then
    raise exception 'New end time must be in the future';
  end if;

  update public.app_maintenance
  set
    ends_at = p_new_ends_at,
    status = case when now() >= starts_at then 'active' else status end,
    updated_by = auth.uid(),
    updated_at = now()
  where id = p_id
  returning * into row;

  return row;
end;
$$;

grant execute on function public.admin_extend_maintenance(uuid, timestamptz) to authenticated;

create or replace function public.admin_end_maintenance_now(p_id uuid)
returns public.app_maintenance
language plpgsql
security definer
set search_path = public
as $$
declare
  row public.app_maintenance;
begin
  if not public.is_admin_operator() then
    raise exception 'Only admin operators can end maintenance';
  end if;

  select * into row from public.app_maintenance where id = p_id for update;
  if not found then
    raise exception 'Maintenance window not found';
  end if;

  if row.status not in ('scheduled', 'active') or row.ended_early_at is not null then
    raise exception 'Maintenance window is already closed';
  end if;

  update public.app_maintenance
  set
    status = 'ended',
    ended_early_at = now(),
    ends_at = least(ends_at, now()),
    updated_by = auth.uid(),
    updated_at = now()
  where id = p_id
  returning * into row;

  return row;
end;
$$;

grant execute on function public.admin_end_maintenance_now(uuid) to authenticated;

create or replace function public.admin_cancel_maintenance(p_id uuid)
returns public.app_maintenance
language plpgsql
security definer
set search_path = public
as $$
declare
  row public.app_maintenance;
begin
  if not public.is_admin_operator() then
    raise exception 'Only admin operators can cancel maintenance';
  end if;

  select * into row from public.app_maintenance where id = p_id for update;
  if not found then
    raise exception 'Maintenance window not found';
  end if;

  if row.status not in ('scheduled', 'active') or row.ended_early_at is not null then
    raise exception 'Maintenance window is already closed';
  end if;

  update public.app_maintenance
  set
    status = 'cancelled',
    ended_early_at = coalesce(ended_early_at, now()),
    updated_by = auth.uid(),
    updated_at = now()
  where id = p_id
  returning * into row;

  return row;
end;
$$;

grant execute on function public.admin_cancel_maintenance(uuid) to authenticated;

notify pgrst, 'reload schema';
