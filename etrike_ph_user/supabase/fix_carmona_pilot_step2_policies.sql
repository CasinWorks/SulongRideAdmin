-- Step 2 of 3 — RLS policies (run AFTER step 1).
-- Run in: Supabase Dashboard → SQL Editor → New query → Run

drop policy if exists "fare_config_select_authenticated" on public.fare_config;
create policy "fare_config_select_authenticated"
  on public.fare_config for select to authenticated
  using (true);

drop policy if exists "fare_config_admin_update" on public.fare_config;
create policy "fare_config_admin_update"
  on public.fare_config for update to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()))
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));

drop policy if exists "fare_config_admin_insert" on public.fare_config;
create policy "fare_config_admin_insert"
  on public.fare_config for insert to authenticated
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));

grant select on table public.fare_config to authenticated;
grant insert, update on table public.fare_config to authenticated;

drop policy if exists "operators_select_self" on public.operators;
create policy "operators_select_self"
  on public.operators for select to authenticated
  using (auth.uid() = id);

grant select on table public.operators to authenticated;

drop policy if exists "drivers_select_admin" on public.drivers;
create policy "drivers_select_admin"
  on public.drivers for select to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()));

drop policy if exists "drivers_update_admin" on public.drivers;
create policy "drivers_update_admin"
  on public.drivers for update to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()))
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));

notify pgrst, 'reload schema';
