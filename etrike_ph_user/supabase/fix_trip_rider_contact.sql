-- Driver (and the rider themselves) can read pickup contact for a trip they
-- already participate in. Does not open public.users to every authenticated
-- account. Phone is withheld on unassigned open requests.
-- Run in Supabase SQL Editor. Safe to re-run.

create or replace function public.get_trip_rider_contact(p_trip_id uuid)
returns table (
  full_name text,
  phone text,
  profile_photo_url text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_trip public.trips%rowtype;
  v_share_phone boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  select * into v_trip from public.trips where id = p_trip_id;
  if not found then
    raise exception 'Trip not found';
  end if;

  if v_trip.status = 'cancelled' then
    raise exception 'Trip is no longer active';
  end if;

  if v_trip.rider_id = auth.uid() then
    v_share_phone := true;
  elsif v_trip.driver_id = auth.uid() then
    v_share_phone := true;
  elsif v_trip.status = 'requested' and v_trip.driver_id is null then
    v_share_phone := false;
  else
    raise exception 'Not allowed to view this rider';
  end if;

  return query
  select
    coalesce(nullif(trim(u.full_name), ''), 'Passenger')::text,
    case
      when v_share_phone then nullif(trim(u.phone), '')
      else null
    end,
    nullif(trim(u.profile_photo_url), '')
  from public.users u
  where u.id = v_trip.rider_id;
end;
$$;

revoke all on function public.get_trip_rider_contact(uuid) from public;
grant execute on function public.get_trip_rider_contact(uuid) to authenticated;

notify pgrst, 'reload schema';
