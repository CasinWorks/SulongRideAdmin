import { supabase } from '../lib/supabase'
import { throwSupabaseError } from '../lib/supabaseError'
import type { PlaceRow } from '../types'
import { logAudit } from './audit'

function mapPlace(row: Record<string, unknown>): PlaceRow {
  return {
    id: String(row.id ?? ''),
    slug: String(row.slug ?? ''),
    name: String(row.name ?? ''),
    display_name: row.display_name != null ? String(row.display_name) : null,
    notes: row.notes != null ? String(row.notes) : null,
    center_lat: Number(row.center_lat ?? 0),
    center_lng: Number(row.center_lng ?? 0),
    radius_km: Number(row.radius_km ?? 5),
    is_active: Boolean(row.is_active ?? true),
    created_at: row.created_at != null ? String(row.created_at) : null,
    updated_at: row.updated_at != null ? String(row.updated_at) : null,
  }
}

export async function listPlaces(): Promise<PlaceRow[]> {
  const { data, error } = await supabase.from('places').select('*').order('name')
  if (error) throwSupabaseError(error, 'Failed to load places. Run fix_places_dispatch_payments.sql.')
  return (data ?? []).map((r) => mapPlace(r as Record<string, unknown>))
}

export async function upsertPlace(input: {
  id?: string
  slug: string
  name: string
  display_name: string
  notes: string
  center_lat: number
  center_lng: number
  radius_km: number
  is_active: boolean
}): Promise<void> {
  const payload = {
    ...(input.id ? { id: input.id } : {}),
    slug: input.slug.trim().toLowerCase().replace(/\s+/g, '-'),
    name: input.name.trim(),
    display_name: input.display_name.trim() || null,
    notes: input.notes.trim() || null,
    center_lat: input.center_lat,
    center_lng: input.center_lng,
    radius_km: input.radius_km,
    is_active: input.is_active,
    updated_at: new Date().toISOString(),
  }
  const { error } = await supabase.from('places').upsert(payload)
  if (error) throwSupabaseError(error, 'Failed to save place')
  await logAudit({
    action: 'place.upsert',
    entityType: 'places',
    entityId: input.id ?? payload.slug,
    summary: `Saved place ${payload.name}`,
    metadata: payload,
  })
}

export async function setOperatorPlace(operatorId: string, placeId: string | null): Promise<void> {
  const { error } = await supabase.from('operators').update({ place_id: placeId }).eq('id', operatorId)
  if (error) throwSupabaseError(error, 'Failed to assign operator place')
}

export async function setDriverPlace(driverId: string, placeId: string | null): Promise<void> {
  const patch: Record<string, unknown> = { place_id: placeId }
  if (placeId) {
    const { data: place } = await supabase
      .from('places')
      .select('name, display_name')
      .eq('id', placeId)
      .maybeSingle()
    if (place) patch.station = String(place.display_name || place.name)
  }
  const { error } = await supabase.from('drivers').update(patch).eq('id', driverId)
  if (error) throwSupabaseError(error, 'Failed to assign driver place')
}

export async function setVehiclePlace(vehicleId: string, placeId: string | null): Promise<void> {
  const { error } = await supabase
    .from('vehicles')
    .update({ place_id: placeId, updated_at: new Date().toISOString() })
    .eq('id', vehicleId)
  if (error) throwSupabaseError(error, 'Failed to assign fleet place')

  const { data: vehicle } = await supabase
    .from('vehicles')
    .select('assigned_driver_id')
    .eq('id', vehicleId)
    .maybeSingle()
  if (vehicle?.assigned_driver_id) {
    await setDriverPlace(String(vehicle.assigned_driver_id), placeId)
  }
}
