-- Operator invite links for Sulong Ride Admin (etrike_ph_admin_web).
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
--
-- Approved super_admin or admin can send invites from the Team page.
-- Each invite has a unique token URL: /invite/{token}
-- Invitee signs in; claim_operator_invite() creates their operators row.

-- ---------------------------------------------------------------------------
-- 1) Helper: approved admin or super_admin
-- ---------------------------------------------------------------------------
create or replace function public.is_admin_operator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.operators o
    where o.id = auth.uid()
      and o.approval_status = 'approved'
      and o.role in ('super_admin', 'admin')
  );
$$;

grant execute on function public.is_admin_operator() to authenticated;

-- ---------------------------------------------------------------------------
-- 2) operator_invites table
-- ---------------------------------------------------------------------------
create table if not exists public.operator_invites (
  id uuid primary key default gen_random_uuid(),
  token text not null unique default encode(gen_random_bytes(24), 'hex'),
  email text not null,
  role text not null default 'viewer',
  status text not null default 'pending',
  invited_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '14 days'),
  accepted_at timestamptz,
  accepted_by uuid references auth.users (id) on delete set null,
  constraint operator_invites_role_check
    check (role in ('super_admin', 'admin', 'viewer')),
  constraint operator_invites_status_check
    check (status in ('pending', 'accepted', 'revoked', 'expired'))
);

create index if not exists operator_invites_email_idx
  on public.operator_invites (lower(email));

create index if not exists operator_invites_status_idx
  on public.operator_invites (status, created_at desc);

alter table public.operator_invites enable row level security;

-- ---------------------------------------------------------------------------
-- 3) RLS: admins manage invites
-- ---------------------------------------------------------------------------
drop policy if exists operator_invites_select_admin on public.operator_invites;
create policy operator_invites_select_admin
  on public.operator_invites for select to authenticated
  using (public.is_admin_operator());

drop policy if exists operator_invites_insert_admin on public.operator_invites;
create policy operator_invites_insert_admin
  on public.operator_invites for insert to authenticated
  with check (
    public.is_admin_operator()
    and invited_by = auth.uid()
    and lower(email) = lower(email)
    and (
      role <> 'super_admin'
      or public.is_super_admin_operator()
    )
  );

drop policy if exists operator_invites_update_admin on public.operator_invites;
create policy operator_invites_update_admin
  on public.operator_invites for update to authenticated
  using (public.is_admin_operator())
  with check (public.is_admin_operator());

grant select, insert, update on table public.operator_invites to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Public preview by token (no auth required)
-- SQL language avoids PL/pgSQL RETURNS TABLE column shadowing (breaks anon RPC).
-- ---------------------------------------------------------------------------
create or replace function public.get_operator_invite_by_token(p_token text)
returns table (
  email text,
  role text,
  status text,
  expires_at timestamptz,
  accepted_at timestamptz
)
language sql
volatile
security definer
set search_path = public
as $$
  with mark_expired as (
    update public.operator_invites i
    set status = 'expired'
    where i.token = p_token
      and i.status = 'pending'
      and i.expires_at < now()
    returning i.id
  )
  select
    i.email,
    i.role,
    i.status,
    i.expires_at,
    i.accepted_at
  from public.operator_invites i
  where i.token = p_token;
$$;

grant execute on function public.get_operator_invite_by_token(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4b) Dual-role exception (operator + driver + rider on same auth user)
-- ---------------------------------------------------------------------------
create or replace function public.is_dual_role_operator_email(p_email text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select lower(coalesce(p_email, '')) = 'christianjoshuacasin@gmail.com';
$$;

grant execute on function public.is_dual_role_operator_email(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Claim invite after sign-in (creates operators row)
-- ---------------------------------------------------------------------------
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

grant execute on function public.claim_operator_invite(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Ensure invite-only operator registration (no self-insert)
-- ---------------------------------------------------------------------------
drop policy if exists "operators_insert_self_pending" on public.operators;
drop policy if exists "operators_insert_super_admin" on public.operators;

notify pgrst, 'reload schema';
