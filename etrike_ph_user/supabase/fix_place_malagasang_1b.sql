-- First live service village: Malagasang 1-B, Imus, Cavite.
-- Run in Supabase SQL Editor after fix_places_dispatch_payments.sql.

insert into public.places (
  slug, name, display_name, notes, center_lat, center_lng, radius_km, is_active
)
values (
  'malagasang-1-b',
  'Malagasang 1-B',
  'Malagasang 1-B, Imus, Cavite',
  'First Sulong Ride service village (Imus). Map and bookings stay inside this barangay.',
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

-- Carmona stays in the table for later, but is not offered as a live area.
update public.places
set is_active = false, updated_at = now()
where slug = 'carmona';

update public.drivers d
set place_id = p.id
from public.places p
where p.slug = 'malagasang-1-b'
  and (
    d.place_id is null
    or d.place_id = (select id from public.places where slug = 'carmona' limit 1)
  );

update public.operators o
set place_id = p.id
from public.places p
where p.slug = 'malagasang-1-b'
  and (
    o.place_id is null
    or o.place_id = (select id from public.places where slug = 'carmona' limit 1)
  );

update public.fare_config
set place_id = (select id from public.places where slug = 'malagasang-1-b' limit 1)
where place_id is null
   or place_id = (select id from public.places where slug = 'carmona' limit 1);

notify pgrst, 'reload schema';
