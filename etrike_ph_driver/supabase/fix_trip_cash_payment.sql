-- Cash payment confirmation timestamp (driver slide-to-confirm before completing trip).
alter table public.trips
  add column if not exists cash_payment_confirmed_at timestamptz;

notify pgrst, 'reload schema';
