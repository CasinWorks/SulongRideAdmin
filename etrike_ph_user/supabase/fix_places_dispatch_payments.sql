-- Places (villages/clients), balanced auto-dispatch, and PayMongo QR payment columns.
-- Run in Supabase SQL Editor after the core 12-script bundle.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Places (one village / client coverage area)
-- ---------------------------------------------------------------------------
create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  display_name text,
  notes text,
  center_lat double precision not null,
  center_lng double precision not null,
  radius_km numeric not null default 5.0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.places (slug, name, display_name, notes, center_lat, center_lng, radius_km, is_active)
values (
  'carmona',
  'Carmona',
  'Carmona, Cavite',
  'Default Sulong Ride coverage for the Carmona pilot.',
  14.3132,
  121.0565,
  8.0,
  false
)
on conflict (slug) do update set
  name = excluded.name,
  display_name = excluded.display_name,
  center_lat = excluded.center_lat,
  center_lng = excluded.center_lng,
  radius_km = excluded.radius_km,
  is_active = false,
  updated_at = now();

insert into public.places (slug, name, display_name, notes, center_lat, center_lng, radius_km, is_active)
values (
  'malagasang-1-b',
  'Malagasang 1-B',
  'Malagasang 1-B, Imus, Cavite',
  'First Sulong Ride service village (Imus).',
  14.3922,
  120.9286,
  1.8,
  true
)
on conflict (slug) do update set
  name = excluded.name,
  display_name = excluded.display_name,
  notes = excluded.notes,
  center_lat = excluded.center_lat,
  center_lng = excluded.center_lng,
  radius_km = excluded.radius_km,
  is_active = true,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- Scope columns
-- ---------------------------------------------------------------------------
alter table public.operators add column if not exists place_id uuid references public.places(id);
alter table public.drivers add column if not exists place_id uuid references public.places(id);
alter table public.trips add column if not exists place_id uuid references public.places(id);
alter table public.fare_config add column if not exists place_id uuid references public.places(id);
alter table public.vehicle_types add column if not exists place_id uuid references public.places(id);

-- PayMongo QR mock / digital payment
alter table public.trips add column if not exists payment_method text not null default 'cash';
alter table public.trips add column if not exists payment_status text not null default 'unpaid';
alter table public.trips add column if not exists payment_ref text;
alter table public.trips add column if not exists paid_at timestamptz;

update public.drivers d
set place_id = p.id
from public.places p
where p.slug = 'malagasang-1-b'
  and d.place_id is null;

update public.fare_config
set place_id = (select id from public.places where slug = 'malagasang-1-b' limit 1)
where place_id is null;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.places enable row level security;

drop policy if exists places_select_authenticated on public.places;
create policy places_select_authenticated
  on public.places for select
  to authenticated
  using (true);

drop policy if exists places_write_operator on public.places;
do $$
begin
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'is_approved_operator'
  ) then
    execute $p$
      create policy places_write_operator
        on public.places for all
        to authenticated
        using (public.is_approved_operator())
        with check (public.is_approved_operator())
    $p$;
  else
    execute $p$
      create policy places_write_operator
        on public.places for all
        to authenticated
        using (true)
        with check (true)
    $p$;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Resolve place from a GPS point (nearest active place whose radius covers it)
-- ---------------------------------------------------------------------------
create or replace function public.place_covering_point(p_lat double precision, p_lng double precision)
returns uuid
language sql
stable
as $$
  select p.id
  from public.places p
  where p.is_active
    and (
      6371 * acos(
        least(1.0, greatest(-1.0,
          cos(radians(p.center_lat)) * cos(radians(p_lat)) *
          cos(radians(p_lng) - radians(p.center_lng)) +
          sin(radians(p.center_lat)) * sin(radians(p_lat))
        ))
      )
    ) <= p.radius_km
  order by
    6371 * acos(
      least(1.0, greatest(-1.0,
        cos(radians(p.center_lat)) * cos(radians(p_lat)) *
        cos(radians(p_lng) - radians(p.center_lng)) +
        sin(radians(p.center_lat)) * sin(radians(p_lat))
      ))
    ) asc
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- Balanced auto-assignment: closest + fewest trips today + longest idle
-- within the place radius (or 5 km default). Auto-accepts — no driver decline.
-- ---------------------------------------------------------------------------
create or replace function public.assign_trip_balanced(p_trip_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip public.trips%rowtype;
  v_place public.places%rowtype;
  v_radius numeric := 5.0;
  v_driver_id uuid;
begin
  select * into v_trip from public.trips where id = p_trip_id for update;
  if not found then
    raise exception 'Trip not found';
  end if;
  if v_trip.status is distinct from 'requested' or v_trip.driver_id is not null then
    return v_trip.driver_id;
  end if;

  if v_trip.place_id is null then
    v_trip.place_id := public.place_covering_point(v_trip.pickup_lat, v_trip.pickup_lng);
    if v_trip.place_id is not null then
      update public.trips set place_id = v_trip.place_id where id = p_trip_id;
    end if;
  end if;

  if v_trip.place_id is not null then
    select * into v_place from public.places where id = v_trip.place_id;
    if found then
      v_radius := coalesce(v_place.radius_km, 5.0);
    end if;
  end if;

  select d.id into v_driver_id
  from public.drivers d
  where d.is_online = true
    and d.is_available = true
    and coalesce(d.approval_status, 'approved') = 'approved'
    and d.current_lat is not null
    and d.current_lng is not null
    and (v_trip.place_id is null or d.place_id is null or d.place_id = v_trip.place_id)
    and not exists (
      select 1 from public.trips t
      where t.driver_id = d.id
        and t.status in ('accepted', 'ongoing')
    )
    and (
      6371 * acos(
        least(1.0, greatest(-1.0,
          cos(radians(d.current_lat)) * cos(radians(v_trip.pickup_lat)) *
          cos(radians(v_trip.pickup_lng) - radians(d.current_lng)) +
          sin(radians(d.current_lat)) * sin(radians(v_trip.pickup_lat))
        ))
      )
    ) <= v_radius
  order by
    (
      6371 * acos(
        least(1.0, greatest(-1.0,
          cos(radians(d.current_lat)) * cos(radians(v_trip.pickup_lat)) *
          cos(radians(v_trip.pickup_lng) - radians(d.current_lng)) +
          sin(radians(d.current_lat)) * sin(radians(v_trip.pickup_lat))
        ))
      )
    ) * 2.0
    + (
      select count(*)::numeric
      from public.trips t
      where t.driver_id = d.id
        and t.status = 'completed'
        and t.created_at >= date_trunc('day', timezone('Asia/Manila', now()))
    ) * 3.0
    + (
      1.0 / (
        0.25 + greatest(
          0,
          extract(epoch from (now() - coalesce(
            (select max(t.completed_at) from public.trips t
             where t.driver_id = d.id and t.status = 'completed'),
            now() - interval '6 hours'
          ))) / 3600.0
        )
      )
    )
  limit 1;

  if v_driver_id is null then
    return null;
  end if;

  update public.trips
  set driver_id = v_driver_id,
      status = 'accepted'
  where id = p_trip_id
    and status = 'requested'
    and driver_id is null;

  update public.drivers
  set is_available = false
  where id = v_driver_id;

  return v_driver_id;
end;
$$;

grant execute on function public.assign_trip_balanced(uuid) to authenticated;
grant execute on function public.place_covering_point(double precision, double precision) to authenticated;

notify pgrst, 'reload schema';
