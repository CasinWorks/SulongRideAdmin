-- Add operator for Sulong Ride Admin (etrike_ph_admin).
-- Supabase Dashboard → SQL Editor → paste all → Run.
--
-- Prerequisite: user must exist in Authentication → Users.
-- If missing: Authentication → Add user → christianjoshuacasin@gmail.com
--   → set password → Auto Confirm User ON.

-- 1) Find auth user (should return 1 row)
select id, email, created_at
from auth.users
where email = 'christianjoshuacasin@gmail.com';

-- 2) Grant operator (id must match auth.users.id exactly)
insert into public.operators (id, email, full_name)
select id, email, 'Christian Joshua Casin'
from auth.users
where email = 'christianjoshuacasin@gmail.com'
on conflict (id) do update
  set email = excluded.email,
      full_name = excluded.full_name;

-- 3) Verify (should return 1 row)
select o.id, o.email, o.full_name, o.created_at
from public.operators o
where o.email = 'christianjoshuacasin@gmail.com';

notify pgrst, 'reload schema';
