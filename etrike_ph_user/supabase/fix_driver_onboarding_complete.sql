-- =============================================================================
-- Sulong Ride — Driver self-service onboarding (RUN ONCE in Supabase SQL Editor)
-- Project: litrignthoxsdvsaheev
-- Order: paste entire file → Run
-- =============================================================================

-- 1) Tables (skip if already created via fix_driver_onboarding.sql)
create table if not exists public.driver_hiring_pipeline (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references auth.users (id) on delete cascade unique,
  current_stage text not null default 'application',
  stage_status text not null default 'in_progress',
  checklist_percent smallint not null default 0 check (checklist_percent between 0 and 100),
  pipeline_percent smallint not null default 0 check (pipeline_percent between 0 and 100),
  interview_at timestamptz,
  contract_due_date date,
  onboarding_due_date date,
  assigned_admin_id uuid references auth.users (id),
  notes text,
  last_reminder_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.driver_documents (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references auth.users (id) on delete cascade,
  doc_type text not null,
  document_number text,
  file_url text,
  file_name text,
  issue_date date,
  expiry_date date,
  status text not null default 'pending',
  admin_notes text,
  verified_by uuid references auth.users (id),
  verified_at timestamptz,
  vehicle_id uuid,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (driver_id, doc_type)
);

create table if not exists public.onboarding_timeline (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references auth.users (id) on delete cascade,
  actor_id uuid references auth.users (id),
  action text not null,
  summary text not null,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.driver_registration_drafts (
  driver_id uuid primary key references auth.users (id) on delete cascade,
  current_step smallint not null default 1 check (current_step between 1 and 7),
  personal_info jsonb not null default '{}',
  employment jsonb not null default '{}',
  updated_at timestamptz not null default now()
);

alter table public.driver_hiring_pipeline enable row level security;
alter table public.driver_documents enable row level security;
alter table public.onboarding_timeline enable row level security;
alter table public.driver_registration_drafts enable row level security;

-- 2) Storage bucket for document photos / PDFs
insert into storage.buckets (id, name, public)
values ('driver-documents', 'driver-documents', true)
on conflict (id) do update set public = true;

-- 3) Driver RLS — insert/read/update own onboarding rows
drop policy if exists driver_documents_driver_write on public.driver_documents;
create policy driver_documents_driver_write on public.driver_documents
  for insert to authenticated with check (auth.uid() = driver_id);

drop policy if exists driver_documents_driver_update on public.driver_documents;
create policy driver_documents_driver_update on public.driver_documents
  for update to authenticated
  using (auth.uid() = driver_id) with check (auth.uid() = driver_id);

drop policy if exists driver_documents_driver_read on public.driver_documents;
create policy driver_documents_driver_read on public.driver_documents
  for select to authenticated using (auth.uid() = driver_id);

drop policy if exists registration_drafts_driver_own on public.driver_registration_drafts;
create policy registration_drafts_driver_own on public.driver_registration_drafts
  for all to authenticated
  using (auth.uid() = driver_id) with check (auth.uid() = driver_id);

drop policy if exists hiring_pipeline_driver_read on public.driver_hiring_pipeline;
create policy hiring_pipeline_driver_read on public.driver_hiring_pipeline
  for select to authenticated using (auth.uid() = driver_id);

drop policy if exists hiring_pipeline_driver_insert on public.driver_hiring_pipeline;
create policy hiring_pipeline_driver_insert on public.driver_hiring_pipeline
  for insert to authenticated with check (auth.uid() = driver_id);

drop policy if exists hiring_pipeline_driver_update on public.driver_hiring_pipeline;
create policy hiring_pipeline_driver_update on public.driver_hiring_pipeline
  for update to authenticated
  using (auth.uid() = driver_id) with check (auth.uid() = driver_id);

drop policy if exists onboarding_timeline_driver_read on public.onboarding_timeline;
create policy onboarding_timeline_driver_read on public.onboarding_timeline
  for select to authenticated using (auth.uid() = driver_id);

drop policy if exists onboarding_timeline_driver_insert on public.onboarding_timeline;
create policy onboarding_timeline_driver_insert on public.onboarding_timeline
  for insert to authenticated with check (auth.uid() = driver_id);

-- 4) Storage RLS — drivers upload to their own folder
drop policy if exists driver_documents_storage_driver_read on storage.objects;
create policy driver_documents_storage_driver_read on storage.objects
  for select to authenticated
  using (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists driver_documents_storage_driver_upload on storage.objects;
create policy driver_documents_storage_driver_upload on storage.objects
  for insert to authenticated
  with check (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists driver_documents_storage_driver_update on storage.objects;
create policy driver_documents_storage_driver_update on storage.objects
  for update to authenticated
  using (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists driver_documents_storage_driver_delete on storage.objects;
create policy driver_documents_storage_driver_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = auth.uid()::text);

grant select, insert, update on public.driver_documents to authenticated;
grant select, insert, update on public.driver_registration_drafts to authenticated;
grant select, insert, update on public.driver_hiring_pipeline to authenticated;
grant select, insert on public.onboarding_timeline to authenticated;

notify pgrst, 'reload schema';
