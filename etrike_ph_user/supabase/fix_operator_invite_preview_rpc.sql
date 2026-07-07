-- Fix public invite link preview (get_operator_invite_by_token RPC).
-- Run in: Supabase Dashboard → SQL Editor
--
-- PL/pgSQL RETURNS TABLE shadowed column names (status, email, etc.) and broke
-- anon/authenticated RPC calls — invite pages showed "Could not load invite".

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

notify pgrst, 'reload schema';
