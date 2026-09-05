-- Assign fleet units to a village, and let drivers set their own service place.
-- Run after fix_places_dispatch_payments.sql (and fix_place_malagasang_1b.sql if used).

alter table public.vehicles
  add column if not exists place_id uuid references public.places (id);

create index if not exists vehicles_place_id_idx on public.vehicles (place_id);

-- Unscoped units follow the first live village (Malagasang 1-B).
update public.vehicles v
set place_id = p.id
from public.places p
where p.slug = 'malagasang-1-b'
  and v.place_id is null;

-- If a unit is already assigned, prefer the driver's village.
update public.vehicles v
set place_id = d.place_id
from public.drivers d
where v.assigned_driver_id = d.id
  and d.place_id is not null
  and (v.place_id is null or v.place_id is distinct from d.place_id);

-- Driver (and their assigned e-trike) can switch service village.
create or replace function public.set_own_service_place(p_place_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  if p_place_id is not null then
    select coalesce(nullif(btrim(display_name), ''), name)
      into v_name
    from public.places
    where id = p_place_id
      and is_active;
    if v_name is null then
      raise exception 'Unknown or inactive service area';
    end if;
  end if;

  update public.drivers
  set place_id = p_place_id,
      station = coalesce(v_name, station)
  where id = auth.uid();

  update public.vehicles
  set place_id = p_place_id,
      updated_at = now()
  where assigned_driver_id = auth.uid();
end;
$$;

revoke all on function public.set_own_service_place(uuid) from public;
grant execute on function public.set_own_service_place(uuid) to authenticated;

notify pgrst, 'reload schema';
