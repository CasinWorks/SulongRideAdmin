-- Invite-only operator access for Sulong Ride Admin (etrike_ph_admin_web).
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
--
-- Stops driver (or any) accounts from self-registering as pending operators on sign-in.
-- Only super admins can insert operator rows (invite flow).

-- ---------------------------------------------------------------------------
-- 1) Remove self-service operator registration
-- ---------------------------------------------------------------------------
drop policy if exists "operators_insert_self_pending" on public.operators;

drop policy if exists "operators_insert_super_admin" on public.operators;
create policy "operators_insert_super_admin"
  on public.operators for insert to authenticated
  with check (public.is_super_admin_operator());

-- ---------------------------------------------------------------------------
-- 2) Optional: remove pending operator rows created by driver self-sign-in
--    (only rows where the same user is also in drivers — not true operators)
-- ---------------------------------------------------------------------------
delete from public.operators o
where o.approval_status = 'pending'
  and exists (
    select 1 from public.drivers d where d.id = o.id
  );

notify pgrst, 'reload schema';
