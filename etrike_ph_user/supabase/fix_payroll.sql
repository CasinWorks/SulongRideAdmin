-- Sulong Ride — payroll (boundary, statutory deductions, cash advances).
-- Admin-configurable rates via payroll_deduction_configs.
-- Run after fix_driver_hr.sql and fix_fleet_management.sql

create table if not exists public.payroll_deduction_configs (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Default PH statutory',
  effective_from date not null default current_date,
  is_active boolean not null default true,
  -- SSS: [{ "msc_min": 0, "msc_max": 5249.99, "employee": 250 }, ...]
  sss_brackets jsonb not null default '[]',
  -- PhilHealth employee share as % of monthly salary (0.05 = 5% total, employee 2.5%)
  philhealth_employee_rate numeric(8, 6) not null default 0.025,
  philhealth_min_contribution numeric(10, 2) not null default 500,
  philhealth_max_contribution numeric(10, 2) not null default 5000,
  -- Pag-IBIG employee rate + cap
  pagibig_employee_rate numeric(8, 6) not null default 0.02,
  pagibig_min_contribution numeric(10, 2) not null default 200,
  pagibig_max_contribution numeric(10, 2) not null default 200,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cash_advances (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references auth.users (id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  balance_remaining numeric(12, 2) not null check (balance_remaining >= 0),
  reason text,
  status text not null default 'open'
    check (status in ('open', 'settled', 'cancelled')),
  issued_at timestamptz not null default now(),
  issued_by uuid references auth.users (id),
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists cash_advances_driver_idx on public.cash_advances (driver_id, status);

create table if not exists public.payroll_records (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references auth.users (id) on delete cascade,
  period_start date not null,
  period_end date not null,
  trip_count integer not null default 0,
  total_fares numeric(12, 2) not null default 0,
  shift_days integer not null default 0,
  boundary_rate numeric(10, 2) not null default 0,
  boundary_total numeric(12, 2) not null default 0,
  gross_pay numeric(12, 2) not null default 0,
  sss_deduction numeric(12, 2) not null default 0,
  philhealth_deduction numeric(12, 2) not null default 0,
  pagibig_deduction numeric(12, 2) not null default 0,
  cash_advance_deduction numeric(12, 2) not null default 0,
  other_deductions numeric(12, 2) not null default 0,
  net_pay numeric(12, 2) not null default 0,
  vehicle_id uuid references public.vehicles (id),
  status text not null default 'draft'
    check (status in ('draft', 'finalized', 'paid')),
  notes text,
  deduction_config_id uuid references public.payroll_deduction_configs (id),
  created_by uuid references auth.users (id),
  finalized_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (driver_id, period_start, period_end)
);

create index if not exists payroll_records_driver_idx on public.payroll_records (driver_id, period_end desc);
create index if not exists payroll_records_period_idx on public.payroll_records (period_start, period_end);

alter table public.payroll_deduction_configs enable row level security;
alter table public.cash_advances enable row level security;
alter table public.payroll_records enable row level security;

drop policy if exists payroll_config_operator_all on public.payroll_deduction_configs;
create policy payroll_config_operator_all on public.payroll_deduction_configs
  for all to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid() and o.approval_status = 'approved'))
  with check (exists (select 1 from public.operators o where o.id = auth.uid() and o.approval_status = 'approved'));

drop policy if exists cash_advances_operator_all on public.cash_advances;
create policy cash_advances_operator_all on public.cash_advances
  for all to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid() and o.approval_status = 'approved'))
  with check (exists (select 1 from public.operators o where o.id = auth.uid() and o.approval_status = 'approved'));

drop policy if exists cash_advances_driver_read on public.cash_advances;
create policy cash_advances_driver_read on public.cash_advances
  for select to authenticated using (auth.uid() = driver_id);

drop policy if exists payroll_records_operator_all on public.payroll_records;
create policy payroll_records_operator_all on public.payroll_records
  for all to authenticated
  using (exists (select 1 from public.operators o where o.id = auth.uid() and o.approval_status = 'approved'))
  with check (exists (select 1 from public.operators o where o.id = auth.uid() and o.approval_status = 'approved'));

drop policy if exists payroll_records_driver_read on public.payroll_records;
create policy payroll_records_driver_read on public.payroll_records
  for select to authenticated using (auth.uid() = driver_id);

grant select, insert, update, delete on public.payroll_deduction_configs to authenticated;
grant select, insert, update, delete on public.cash_advances to authenticated;
grant select, insert, update, delete on public.payroll_records to authenticated;

-- Seed default config (2025-style simplified SSS MSC brackets — edit in admin Payroll → Settings)
insert into public.payroll_deduction_configs (name, effective_from, is_active, sss_brackets, notes)
select
  'PH Statutory 2025 (editable)',
  '2025-01-01',
  true,
  '[
    {"msc_min": 0, "msc_max": 5249.99, "employee": 250},
    {"msc_min": 5250, "msc_max": 5749.99, "employee": 275},
    {"msc_min": 5750, "msc_max": 6249.99, "employee": 300},
    {"msc_min": 6250, "msc_max": 6749.99, "employee": 325},
    {"msc_min": 6750, "msc_max": 7249.99, "employee": 350},
    {"msc_min": 7250, "msc_max": 7749.99, "employee": 375},
    {"msc_min": 7750, "msc_max": 8249.99, "employee": 400},
    {"msc_min": 8250, "msc_max": 8749.99, "employee": 425},
    {"msc_min": 8750, "msc_max": 9249.99, "employee": 450},
    {"msc_min": 9250, "msc_max": 9749.99, "employee": 475},
    {"msc_min": 9750, "msc_max": 10249.99, "employee": 500},
    {"msc_min": 10250, "msc_max": 10749.99, "employee": 525},
    {"msc_min": 10750, "msc_max": 11249.99, "employee": 550},
    {"msc_min": 11250, "msc_max": 11749.99, "employee": 575},
    {"msc_min": 11750, "msc_max": 12249.99, "employee": 600},
    {"msc_min": 12250, "msc_max": 12749.99, "employee": 625},
    {"msc_min": 12750, "msc_max": 13249.99, "employee": 650},
    {"msc_min": 13250, "msc_max": 13749.99, "employee": 675},
    {"msc_min": 13750, "msc_max": 14249.99, "employee": 700},
    {"msc_min": 14250, "msc_max": 14749.99, "employee": 725},
    {"msc_min": 14750, "msc_max": 15249.99, "employee": 750},
    {"msc_min": 15250, "msc_max": 15749.99, "employee": 775},
    {"msc_min": 15750, "msc_max": 16249.99, "employee": 800},
    {"msc_min": 16250, "msc_max": 16749.99, "employee": 825},
    {"msc_min": 16750, "msc_max": 17249.99, "employee": 850},
    {"msc_min": 17250, "msc_max": 17749.99, "employee": 875},
    {"msc_min": 17750, "msc_max": 18249.99, "employee": 900},
    {"msc_min": 18250, "msc_max": 18749.99, "employee": 925},
    {"msc_min": 18750, "msc_max": 19249.99, "employee": 950},
    {"msc_min": 19250, "msc_max": 19749.99, "employee": 975},
    {"msc_min": 19750, "msc_max": 20249.99, "employee": 1000},
    {"msc_min": 20250, "msc_max": 99999999, "employee": 1000}
  ]'::jsonb,
  'Default seed — update brackets when SSS/PhilHealth/Pag-IBIG circulars change. Admin → Payroll → Settings.'
where not exists (select 1 from public.payroll_deduction_configs limit 1);

notify pgrst, 'reload schema';
