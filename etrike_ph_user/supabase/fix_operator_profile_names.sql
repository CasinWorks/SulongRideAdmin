-- Operator display names: self-service + admin edits (etrike_ph_admin_web).
-- Run in: Supabase Dashboard → SQL Editor

-- Admins can read all operator rows (for Team name management).
drop policy if exists "operators_select_self" on public.operators;
create policy "operators_select_team"
  on public.operators for select to authenticated
  using (auth.uid() = id or public.is_admin_operator());

create or replace function public.update_operator_self_name(p_full_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := trim(coalesce(p_full_name, ''));
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if length(v_name) < 2 or length(v_name) > 80 then
    raise exception 'Name must be 2–80 characters';
  end if;

  update public.operators o
  set full_name = v_name
  where o.id = auth.uid();
end;
$$;

create or replace function public.update_operator_name_by_admin(
  p_operator_id uuid,
  p_full_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := trim(coalesce(p_full_name, ''));
begin
  if not public.is_admin_operator() then
    raise exception 'Not authorized';
  end if;

  if length(v_name) < 2 or length(v_name) > 80 then
    raise exception 'Name must be 2–80 characters';
  end if;

  update public.operators o
  set full_name = v_name
  where o.id = p_operator_id;
end;
$$;

grant execute on function public.update_operator_self_name(text) to authenticated;
grant execute on function public.update_operator_name_by_admin(uuid, text) to authenticated;

notify pgrst, 'reload schema';
