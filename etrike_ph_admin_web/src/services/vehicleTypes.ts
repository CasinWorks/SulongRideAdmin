import { supabase } from '../lib/supabase'
import { throwSupabaseError } from '../lib/supabaseError'
import type { VehicleTypeRow } from '../types'
import { logAudit } from './audit'

function mapVehicleType(row: Record<string, unknown>): VehicleTypeRow {
  return {
    id: String(row.id ?? ''),
    name: String(row.name ?? ''),
    description: String(row.description ?? ''),
    icon: String(row.icon ?? '🛺'),
    eta_minutes: Number(row.eta_minutes ?? 3),
    sort_order: Number(row.sort_order ?? 0),
    is_active: Boolean(row.is_active ?? true),
    updated_at: row.updated_at != null ? String(row.updated_at) : null,
  }
}

export async function listVehicleTypes(): Promise<VehicleTypeRow[]> {
  const { data, error } = await supabase
    .from('vehicle_types')
    .select('*')
    .order('sort_order', { ascending: true })
    .order('name', { ascending: true })
  if (error) throwSupabaseError(error, 'Failed to load vehicle types')
  return (data ?? []).map((r) => mapVehicleType(r as Record<string, unknown>))
}

export async function upsertVehicleType(input: {
  id: string
  name: string
  description: string
  icon: string
  eta_minutes: number
  sort_order: number
  is_active: boolean
}): Promise<void> {
  const payload = {
    id: input.id.trim(),
    name: input.name.trim(),
    description: input.description.trim(),
    icon: input.icon.trim() || '🛺',
    eta_minutes: input.eta_minutes,
    sort_order: input.sort_order,
    is_active: input.is_active,
    updated_at: new Date().toISOString(),
  }

  const { error } = await supabase.from('vehicle_types').upsert(payload, { onConflict: 'id' })
  if (error) throwSupabaseError(error, 'Failed to save vehicle type')

  await logAudit({
    action: 'fleet.vehicle_type.upsert',
    entityType: 'vehicle_types',
    entityId: payload.id,
    summary: `Saved vehicle type ${payload.name}`,
    metadata: payload,
  })
}

export async function setVehicleTypeActive(id: string, active: boolean): Promise<void> {
  const { error } = await supabase
    .from('vehicle_types')
    .update({ is_active: active, updated_at: new Date().toISOString() })
    .eq('id', id)
  if (error) throwSupabaseError(error, 'Failed to update vehicle type')

  await logAudit({
    action: 'fleet.vehicle_type.toggle',
    entityType: 'vehicle_types',
    entityId: id,
    summary: active ? 'Enabled vehicle type' : 'Disabled vehicle type',
    metadata: { is_active: active },
  })
}

export async function deleteVehicleType(id: string): Promise<void> {
  const { error } = await supabase.from('vehicle_types').delete().eq('id', id)
  if (error) throwSupabaseError(error, 'Failed to delete vehicle type')

  await logAudit({
    action: 'fleet.vehicle_type.delete',
    entityType: 'vehicle_types',
    entityId: id,
    summary: 'Deleted vehicle type',
  })
}

