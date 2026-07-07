-- Immutable audit trail for operator, driver, and rider actions.
-- Run in Supabase Dashboard → SQL Editor.

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  actor_id uuid references auth.users (id) on delete set null,
  actor_role text not null check (actor_role in ('operator', 'driver', 'rider')),
  actor_email text,
  actor_name text,
  action text not null,
  entity_type text,
  entity_id text,
  summary text not null,
  metadata jsonb not null default '{}'::jsonb,
  app_source text not null check (app_source in ('admin', 'driver', 'rider'))
);

create index if not exists audit_logs_created_at_idx
  on public.audit_logs (created_at desc);

create index if not exists audit_logs_actor_id_idx
  on public.audit_logs (actor_id);

create index if not exists audit_logs_action_idx
  on public.audit_logs (action);

create index if not exists audit_logs_entity_idx
  on public.audit_logs (entity_type, entity_id);

alter table public.audit_logs enable row level security;

drop policy if exists "audit_insert_own" on public.audit_logs;
create policy "audit_insert_own"
  on public.audit_logs for insert to authenticated
  with check (actor_id = auth.uid());

drop policy if exists "audit_select_admin" on public.audit_logs;
create policy "audit_select_admin"
  on public.audit_logs for select to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()));

notify pgrst, 'reload schema';
