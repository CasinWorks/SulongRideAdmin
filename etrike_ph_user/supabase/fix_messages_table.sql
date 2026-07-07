-- Run in Supabase → SQL Editor (same project as keys.dart).
-- Fixes PGRST205: Could not find the table 'public.messages' in the schema cache.

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  sender_role text not null check (sender_role in ('rider', 'driver')),
  message text not null,
  created_at timestamptz not null default now(),
  delivered_at timestamptz,
  read_at timestamptz
);

create index if not exists messages_trip_id_created_at_idx
  on public.messages (trip_id, created_at);

alter table public.messages enable row level security;

drop policy if exists "messages_select_trip_participant" on public.messages;
create policy "messages_select_trip_participant"
  on public.messages for select to authenticated
  using (
    exists (
      select 1 from public.trips t
      where t.id = trip_id
        and (t.rider_id = auth.uid() or t.driver_id = auth.uid())
    )
  );

drop policy if exists "messages_insert_trip_participant" on public.messages;
create policy "messages_insert_trip_participant"
  on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.trips t
      where t.id = trip_id
        and (t.rider_id = auth.uid() or t.driver_id = auth.uid())
    )
  );

grant select, insert on table public.messages to authenticated;

alter table public.messages add column if not exists delivered_at timestamptz;
alter table public.messages add column if not exists read_at timestamptz;

drop policy if exists "messages_update_delivery" on public.messages;
create policy "messages_update_delivery"
  on public.messages for update to authenticated
  using (
    sender_id <> auth.uid()
    and exists (
      select 1 from public.trips t
      where t.id = trip_id
        and (t.rider_id = auth.uid() or t.driver_id = auth.uid())
    )
  )
  with check (
    sender_id <> auth.uid()
    and exists (
      select 1 from public.trips t
      where t.id = trip_id
        and (t.rider_id = auth.uid() or t.driver_id = auth.uid())
    )
  );

grant update on table public.messages to authenticated;

notify pgrst, 'reload schema';

-- Optional: Dashboard → Database → Publications → supabase_realtime → add `messages`
-- for instant chat updates (poll/reopen still works without it).

select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'messages'
order by ordinal_position;
