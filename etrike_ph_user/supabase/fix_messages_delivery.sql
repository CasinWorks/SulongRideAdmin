-- Run in Supabase → SQL Editor after fix_messages_table.sql.
-- Adds delivery/read receipts for iMessage-style chat status.

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
