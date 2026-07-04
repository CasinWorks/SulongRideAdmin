-- Sulong Ride — driver rider-protocol training (online quiz + onsite attendance).
-- Run in Supabase SQL Editor (dev/staging/prod). Safe to re-run.

create table if not exists public.driver_training (
  driver_id uuid primary key references auth.users (id) on delete cascade,
  status text not null default 'not_started'
    check (status in ('not_started', 'in_progress', 'completed')),
  mode text not null default 'online'
    check (mode in ('online', 'onsite')),
  started_at timestamptz,
  completed_at timestamptz,
  completed_by uuid references auth.users (id),
  quiz_passed_at timestamptz,
  quiz_score smallint check (quiz_score is null or (quiz_score between 0 and 100)),
  quiz_answers jsonb not null default '{}',
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists driver_training_status_idx on public.driver_training (status);
create index if not exists driver_training_mode_idx on public.driver_training (mode);

alter table public.driver_training enable row level security;

drop policy if exists driver_training_driver_read on public.driver_training;
create policy driver_training_driver_read on public.driver_training
  for select to authenticated using (auth.uid() = driver_id);

drop policy if exists driver_training_driver_write on public.driver_training;
create policy driver_training_driver_write on public.driver_training
  for insert to authenticated with check (auth.uid() = driver_id);

drop policy if exists driver_training_driver_update on public.driver_training;
create policy driver_training_driver_update on public.driver_training
  for update to authenticated
  using (auth.uid() = driver_id) with check (auth.uid() = driver_id);

drop policy if exists driver_training_operator_all on public.driver_training;
create policy driver_training_operator_all on public.driver_training
  for all to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid() and o.approval_status = 'approved'))
  with check (exists (select 1 from public.operators o where o.id = auth.uid() and o.approval_status = 'approved'));

grant select, insert, update on public.driver_training to authenticated;

notify pgrst, 'reload schema';
