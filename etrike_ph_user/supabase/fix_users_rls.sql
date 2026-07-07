-- Run in Supabase → SQL Editor
-- Fixes: PostgrestException row-level security policy for table "users", code 42501
-- Cause: app upserts public.users after signUp; RLS must allow authenticated users
--        to insert/select/update only their own row (id = auth.uid()).

alter table public.users enable row level security;

drop policy if exists "users_insert_own" on public.users;
create policy "users_insert_own"
  on public.users
  for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "users_select_own" on public.users;
create policy "users_select_own"
  on public.users
  for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own"
  on public.users
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

grant select, insert, update on table public.users to authenticated;

notify pgrst, 'reload schema';
