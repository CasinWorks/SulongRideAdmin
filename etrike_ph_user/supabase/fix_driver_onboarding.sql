-- Sulong Ride: company e-trike fleet, driver onboarding, documents, hiring pipeline.
-- Run after fix_driver_hr.sql

-- Company-owned vehicles (operator provides tricycles)
create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  unit_number text not null unique,
  plate_number text not null unique,
  model text,
  status text not null default 'available'
    check (status in ('available', 'assigned', 'maintenance', 'retired')),
  assigned_driver_id uuid references auth.users (id) on delete set null,
  boundary_fee numeric(10, 2) default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists vehicles_status_idx on public.vehicles (status);
create index if not exists vehicles_assigned_driver_idx on public.vehicles (assigned_driver_id);

-- Document types tracked for e-trike company drivers
create table if not exists public.driver_documents (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references auth.users (id) on delete cascade,
  doc_type text not null,
  document_number text,
  file_url text,
  file_name text,
  issue_date date,
  expiry_date date,
  status text not null default 'pending'
    check (status in (
      'pending', 'verified', 'rejected', 'expiring_soon', 'expired', 'not_required', 'does_not_expire'
    )),
  admin_notes text,
  verified_by uuid references auth.users (id),
  verified_at timestamptz,
  vehicle_id uuid references public.vehicles (id),
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (driver_id, doc_type)
);

create index if not exists driver_documents_driver_idx on public.driver_documents (driver_id);
create index if not exists driver_documents_expiry_idx on public.driver_documents (expiry_date)
  where expiry_date is not null;

-- Hiring pipeline stages
create table if not exists public.driver_hiring_pipeline (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references auth.users (id) on delete cascade unique,
  current_stage text not null default 'application'
    check (current_stage in (
      'application', 'interview_scheduled', 'interview_completed',
      'offer_hiring', 'onboarding', 'contract_signing', 'approved_active'
    )),
  stage_status text not null default 'in_progress'
    check (stage_status in ('not_started', 'in_progress', 'completed', 'failed', 'on_hold')),
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

-- Timeline: reminders, deadlines, stage changes
create table if not exists public.onboarding_timeline (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references auth.users (id) on delete cascade,
  actor_id uuid references auth.users (id),
  action text not null,
  summary text not null,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists onboarding_timeline_driver_idx on public.onboarding_timeline (driver_id, created_at desc);

-- Registration draft (wizard in-progress JSON)
create table if not exists public.driver_registration_drafts (
  driver_id uuid primary key references auth.users (id) on delete cascade,
  current_step smallint not null default 1 check (current_step between 1 and 7),
  personal_info jsonb not null default '{}',
  employment jsonb not null default '{}',
  updated_at timestamptz not null default now()
);

-- Auto-update document status from expiry dates
create or replace function public.refresh_driver_document_status()
returns trigger
language plpgsql
as $$
begin
  if new.expiry_date is null then
    if new.status not in ('verified', 'rejected', 'pending', 'not_required', 'does_not_expire') then
      null;
    end if;
    return new;
  end if;

  if new.expiry_date < current_date then
    new.status := 'expired';
  elsif new.expiry_date <= current_date + interval '60 days' then
    if new.status = 'verified' then
      new.status := 'expiring_soon';
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_driver_documents_expiry on public.driver_documents;
create trigger trg_driver_documents_expiry
  before insert or update of expiry_date, status on public.driver_documents
  for each row execute function public.refresh_driver_document_status();

-- RLS: operators full access
alter table public.vehicles enable row level security;
alter table public.driver_documents enable row level security;
alter table public.driver_hiring_pipeline enable row level security;
alter table public.onboarding_timeline enable row level security;
alter table public.driver_registration_drafts enable row level security;

drop policy if exists vehicles_operator_all on public.vehicles;
create policy vehicles_operator_all on public.vehicles
  for all to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()))
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));

drop policy if exists driver_documents_operator_all on public.driver_documents;
create policy driver_documents_operator_all on public.driver_documents
  for all to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()))
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));

drop policy if exists driver_documents_driver_read on public.driver_documents;
create policy driver_documents_driver_read on public.driver_documents
  for select to authenticated
  using (auth.uid() = driver_id);

drop policy if exists hiring_pipeline_operator_all on public.driver_hiring_pipeline;
create policy hiring_pipeline_operator_all on public.driver_hiring_pipeline
  for all to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()))
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));

drop policy if exists onboarding_timeline_operator_all on public.onboarding_timeline;
create policy onboarding_timeline_operator_all on public.onboarding_timeline
  for all to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()))
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));

drop policy if exists registration_drafts_operator_all on public.driver_registration_drafts;
create policy registration_drafts_operator_all on public.driver_registration_drafts
  for all to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid()))
  with check (exists (select 1 from public.operators o where o.id = auth.uid()));
