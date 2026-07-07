-- Allow one auth user to hold operator + driver + rider roles (admin web exception).
-- Run in: Supabase Dashboard → SQL Editor

create or replace function public.is_dual_role_operator_email(p_email text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select lower(coalesce(p_email, '')) = 'christianjoshuacasin@gmail.com';
$$;

grant execute on function public.is_dual_role_operator_email(text) to authenticated;

create or replace function public.claim_operator_invite(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_user_email text;
  v_invite public.operator_invites%rowtype;
  v_full_name text;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select lower(u.email)
  into v_user_email
  from auth.users u
  where u.id = v_user_id;

  if v_user_email is null then
    raise exception 'Account email not found';
  end if;

  if exists (select 1 from public.drivers d where d.id = v_user_id)
     and not public.is_dual_role_operator_email(v_user_email) then
    raise exception 'Driver accounts cannot join the operator dashboard';
  end if;

  update public.operator_invites i
  set status = 'expired'
  where i.token = p_token
    and i.status = 'pending'
    and i.expires_at < now();

  select *
  into v_invite
  from public.operator_invites i
  where i.token = p_token;

  if not found then
    raise exception 'Invite not found';
  end if;

  if v_invite.status = 'accepted' then
    return jsonb_build_object('status', 'accepted', 'already_claimed', true);
  end if;

  if v_invite.status <> 'pending' then
    raise exception 'Invite is no longer valid';
  end if;

  if lower(v_invite.email) <> v_user_email then
    raise exception 'Sign in with % to accept this invite', v_invite.email;
  end if;

  select coalesce(
    u.raw_user_meta_data->>'full_name',
    u.raw_user_meta_data->>'name',
    split_part(v_user_email, '@', 1)
  )
  into v_full_name
  from auth.users u
  where u.id = v_user_id;

  insert into public.operators (id, email, full_name, approval_status, role)
  values (v_user_id, v_user_email, v_full_name, 'pending', v_invite.role)
  on conflict (id) do update
    set
      email = excluded.email,
      full_name = coalesce(nullif(public.operators.full_name, ''), excluded.full_name),
      role = excluded.role,
      approval_status = case
        when public.operators.approval_status = 'approved' then 'approved'
        else 'pending'
      end;

  update public.operator_invites i
  set
    status = 'accepted',
    accepted_at = now(),
    accepted_by = v_user_id
  where i.id = v_invite.id;

  return jsonb_build_object('status', 'accepted', 'role', v_invite.role);
end;
$$;

notify pgrst, 'reload schema';
