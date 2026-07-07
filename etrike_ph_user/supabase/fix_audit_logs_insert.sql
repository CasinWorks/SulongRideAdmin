-- Fix audit log inserts for all operators (not only super admin).
-- Run in: Supabase Dashboard → SQL Editor
--
-- Problem: audit_insert_own required is_approved_operator(), so pending operators,
-- drivers, and some admin actions failed silently (only super_admin traces showed).

-- ---------------------------------------------------------------------------
-- 1) actor_role check — keep operator RBAC values
-- ---------------------------------------------------------------------------
alter table public.audit_logs
  drop constraint if exists audit_logs_actor_role_check;

alter table public.audit_logs
  add constraint audit_logs_actor_role_check
  check (
    actor_role in (
      'operator',
      'driver',
      'rider',
      'super_admin',
      'admin',
      'viewer'
    )
  );

-- ---------------------------------------------------------------------------
-- 2) Any authenticated user may insert their own audit row
-- ---------------------------------------------------------------------------
drop policy if exists "audit_insert_own" on public.audit_logs;
create policy "audit_insert_own"
  on public.audit_logs for insert to authenticated
  with check (actor_id = auth.uid());

drop policy if exists "audit_select_admin" on public.audit_logs;
create policy "audit_select_admin"
  on public.audit_logs for select to authenticated
  using (public.is_approved_operator());

grant select, insert on table public.audit_logs to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Security-definer insert (bypasses RLS edge cases, resolves actor fields)
-- ---------------------------------------------------------------------------
create or replace function public.insert_audit_log(
  p_action text,
  p_summary text,
  p_entity_type text default null,
  p_entity_id text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_app_source text default 'admin'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_name text;
  v_role text := 'operator';
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if length(trim(coalesce(p_action, ''))) = 0 then
    raise exception 'Action is required';
  end if;

  if length(trim(coalesce(p_summary, ''))) = 0 then
    raise exception 'Summary is required';
  end if;

  select
    u.email,
    coalesce(
      nullif(trim(o.full_name), ''),
      nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
      nullif(trim(u.raw_user_meta_data->>'name'), '')
    ),
    coalesce(nullif(trim(o.role), ''), 'operator')
  into v_email, v_name, v_role
  from auth.users u
  left join public.operators o on o.id = u.id
  where u.id = v_user_id;

  if v_role not in ('super_admin', 'admin', 'viewer') then
    if exists (select 1 from public.drivers d where d.id = v_user_id) then
      v_role := 'driver';
    elsif v_role = 'operator' and not exists (
      select 1 from public.operators o where o.id = v_user_id
    ) then
      v_role := 'rider';
    end if;
  end if;

  if v_role not in ('operator', 'driver', 'rider', 'super_admin', 'admin', 'viewer') then
    v_role := 'operator';
  end if;

  if p_app_source not in ('admin', 'driver', 'rider') then
    raise exception 'Invalid app_source';
  end if;

  insert into public.audit_logs (
    actor_id,
    actor_email,
    actor_name,
    actor_role,
    action,
    entity_type,
    entity_id,
    summary,
    metadata,
    app_source
  )
  values (
    v_user_id,
    v_email,
    v_name,
    v_role,
    trim(p_action),
    nullif(trim(p_entity_type), ''),
    nullif(trim(p_entity_id), ''),
    trim(p_summary),
    coalesce(p_metadata, '{}'::jsonb),
    p_app_source
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.insert_audit_log(text, text, text, text, jsonb, text) to authenticated;

notify pgrst, 'reload schema';
