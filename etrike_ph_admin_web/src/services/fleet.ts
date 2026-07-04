import { supabase } from '../lib/supabase'
import { throwSupabaseError } from '../lib/supabaseError'
import { DEFAULT_STATION } from '../lib/onboardingConstants'
import { logAudit } from './audit'
import type {
  AssignVehicleInput,
  FleetVehicle,
  FleetVehicleWithDriver,
  MaintenanceLogInput,
  VehicleAssignmentRow,
  VehicleFormInput,
  VehicleMaintenanceLog,
  VehicleStatus,
} from '../types/fleet'

function mapVehicle(row: Record<string, unknown>): FleetVehicle {
  return {
    id: String(row.id),
    unit_number: String(row.unit_number ?? ''),
    plate_number: String(row.plate_number ?? ''),
    model: row.model != null ? String(row.model) : null,
    color: row.color != null ? String(row.color) : null,
    year_manufactured:
      row.year_manufactured != null ? Number(row.year_manufactured) : null,
    status: String(row.status ?? 'available') as VehicleStatus,
    assigned_driver_id:
      row.assigned_driver_id != null ? String(row.assigned_driver_id) : null,
    boundary_fee: Number(row.boundary_fee ?? 0),
    notes: row.notes != null ? String(row.notes) : null,
    assigned_at: row.assigned_at != null ? String(row.assigned_at) : null,
    last_maintenance_at:
      row.last_maintenance_at != null ? String(row.last_maintenance_at) : null,
    next_maintenance_due:
      row.next_maintenance_due != null ? String(row.next_maintenance_due) : null,
    created_at: String(row.created_at ?? ''),
    updated_at: String(row.updated_at ?? ''),
  }
}

function mapAssignment(row: Record<string, unknown>): VehicleAssignmentRow {
  return {
    id: String(row.id),
    vehicle_id: String(row.vehicle_id),
    driver_id: String(row.driver_id),
    status: row.status as VehicleAssignmentRow['status'],
    effective_from: String(row.effective_from),
    effective_to: row.effective_to != null ? String(row.effective_to) : null,
    assigned_by: row.assigned_by != null ? String(row.assigned_by) : null,
    notes: row.notes != null ? String(row.notes) : null,
    created_at: String(row.created_at ?? ''),
    updated_at: String(row.updated_at ?? ''),
  }
}

function mapMaintenance(row: Record<string, unknown>): VehicleMaintenanceLog {
  return {
    id: String(row.id),
    vehicle_id: String(row.vehicle_id),
    logged_by: row.logged_by != null ? String(row.logged_by) : null,
    maintenance_type: row.maintenance_type as VehicleMaintenanceLog['maintenance_type'],
    description: String(row.description ?? ''),
    cost: row.cost != null ? Number(row.cost) : null,
    odometer_km: row.odometer_km != null ? Number(row.odometer_km) : null,
    performed_at: String(row.performed_at ?? ''),
    next_due_date: row.next_due_date != null ? String(row.next_due_date) : null,
    created_at: String(row.created_at ?? ''),
  }
}

async function operatorId(): Promise<string | null> {
  const {
    data: { user },
  } = await supabase.auth.getUser()
  return user?.id ?? null
}

export async function listFleetVehicles(
  statusFilter?: VehicleStatus,
): Promise<FleetVehicleWithDriver[]> {
  let query = supabase.from('vehicles').select('*').order('unit_number')
  if (statusFilter) query = query.eq('status', statusFilter)
  const { data, error } = await query
  if (error) throwSupabaseError(error, 'Failed to load fleet')

  const vehicles = (data ?? []).map((r) => mapVehicle(r as Record<string, unknown>))
  const driverIds = [
    ...new Set(vehicles.map((v) => v.assigned_driver_id).filter(Boolean)),
  ] as string[]

  let driverMap = new Map<string, { full_name: string; email: string }>()
  if (driverIds.length) {
    const { data: drivers } = await supabase
      .from('drivers')
      .select('id, full_name, email')
      .in('id', driverIds)
    driverMap = new Map(
      (drivers ?? []).map((d) => [
        String(d.id),
        { full_name: String(d.full_name ?? ''), email: String(d.email ?? '') },
      ]),
    )
  }

  return vehicles.map((v) => {
    const d = v.assigned_driver_id ? driverMap.get(v.assigned_driver_id) : null
    return {
      ...v,
      assigned_driver_name: d?.full_name ?? null,
      assigned_driver_email: d?.email ?? null,
    }
  })
}

export async function fetchFleetVehicle(id: string): Promise<FleetVehicleWithDriver | null> {
  const rows = await listFleetVehicles()
  return rows.find((v) => v.id === id) ?? null
}

export async function createVehicle(input: VehicleFormInput): Promise<FleetVehicle> {
  const now = new Date().toISOString()
  const { data, error } = await supabase
    .from('vehicles')
    .insert({
      unit_number: input.unit_number.trim(),
      plate_number: input.plate_number.trim(),
      model: input.model?.trim() || null,
      color: input.color?.trim() || null,
      year_manufactured: input.year_manufactured ?? null,
      boundary_fee: input.boundary_fee ?? 0,
      status: input.status ?? 'available',
      notes: input.notes?.trim() || null,
      next_maintenance_due: input.next_maintenance_due || null,
      created_at: now,
      updated_at: now,
    })
    .select('*')
    .single()
  if (error) throwSupabaseError(error, 'Failed to create vehicle')
  await logAudit({
    action: 'fleet.vehicle.create',
    entityType: 'vehicles',
    entityId: String(data.id),
    summary: `Added fleet unit ${input.unit_number}`,
  })
  return mapVehicle(data as Record<string, unknown>)
}

export async function updateVehicle(
  id: string,
  input: Partial<VehicleFormInput>,
): Promise<FleetVehicle> {
  const payload: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
  }
  if (input.unit_number != null) payload.unit_number = input.unit_number.trim()
  if (input.plate_number != null) payload.plate_number = input.plate_number.trim()
  if (input.model !== undefined) payload.model = input.model?.trim() || null
  if (input.color !== undefined) payload.color = input.color?.trim() || null
  if (input.year_manufactured !== undefined) payload.year_manufactured = input.year_manufactured
  if (input.boundary_fee !== undefined) payload.boundary_fee = input.boundary_fee
  if (input.status != null) payload.status = input.status
  if (input.notes !== undefined) payload.notes = input.notes?.trim() || null
  if (input.next_maintenance_due !== undefined) {
    payload.next_maintenance_due = input.next_maintenance_due || null
  }

  const { data, error } = await supabase
    .from('vehicles')
    .update(payload)
    .eq('id', id)
    .select('*')
    .single()
  if (error) throwSupabaseError(error, 'Failed to update vehicle')
  await logAudit({
    action: 'fleet.vehicle.update',
    entityType: 'vehicles',
    entityId: id,
    summary: `Updated fleet unit ${data.unit_number}`,
  })
  return mapVehicle(data as Record<string, unknown>)
}

export async function retireVehicle(id: string): Promise<void> {
  const vehicle = await fetchFleetVehicle(id)
  if (vehicle?.assigned_driver_id) {
    await unassignVehicleFromDriver(vehicle.assigned_driver_id, 'Vehicle retired')
  }
  await updateVehicle(id, { status: 'retired' })
}

export async function listAvailableVehiclesForDriver(driverId?: string): Promise<FleetVehicle[]> {
  const all = await listFleetVehicles()
  return all.filter(
    (v) =>
      v.status !== 'retired' &&
      v.status !== 'maintenance' &&
      (v.status === 'available' || v.assigned_driver_id === driverId),
  )
}

/** Assign company e-trike to driver (immediate or scheduled). */
export async function assignVehicleToDriver(input: AssignVehicleInput): Promise<void> {
  const vehicle = await fetchFleetVehicle(input.vehicle_id)
  if (!vehicle) throw new Error('Vehicle not found')
  if (vehicle.status === 'retired') throw new Error('Cannot assign a retired unit')

  const effectiveFrom = input.effective_from
    ? new Date(input.effective_from)
    : new Date()
  const isScheduled = effectiveFrom.getTime() > Date.now() + 60_000
  const opId = await operatorId()
  const now = new Date().toISOString()

  const { data: driver, error: driverErr } = await supabase
    .from('drivers')
    .select('id, full_name')
    .eq('id', input.driver_id)
    .maybeSingle()
  if (driverErr) throwSupabaseError(driverErr, 'Failed to load driver')
  if (!driver) throw new Error('Driver not found')

  if (isScheduled) {
    await supabase.from('vehicle_assignments').insert({
      vehicle_id: input.vehicle_id,
      driver_id: input.driver_id,
      status: 'scheduled',
      effective_from: effectiveFrom.toISOString(),
      effective_to: input.effective_to ?? null,
      assigned_by: opId,
      notes: input.notes?.trim() || null,
      created_at: now,
      updated_at: now,
    })
    await logAudit({
      action: 'fleet.assign.scheduled',
      entityType: 'vehicles',
      entityId: input.vehicle_id,
      summary: `Scheduled unit ${vehicle.unit_number} for ${driver.full_name}`,
      metadata: { driver_id: input.driver_id, effective_from: effectiveFrom.toISOString() },
    })
    return
  }

  await activateVehicleAssignment({
    vehicleId: input.vehicle_id,
    driverId: input.driver_id,
    vehicle,
    notes: input.notes,
    effectiveTo: input.effective_to ?? null,
    opId,
  })
}

async function activateVehicleAssignment({
  vehicleId,
  driverId,
  vehicle,
  notes,
  effectiveTo,
  opId,
}: {
  vehicleId: string
  driverId: string
  vehicle: FleetVehicle
  notes?: string
  effectiveTo?: string | null
  opId: string | null
}): Promise<void> {
  const now = new Date().toISOString()

  // End other active assignments for this vehicle or driver
  await supabase
    .from('vehicle_assignments')
    .update({ status: 'ended', effective_to: now, updated_at: now })
    .eq('vehicle_id', vehicleId)
    .eq('status', 'active')

  await supabase
    .from('vehicle_assignments')
    .update({ status: 'ended', effective_to: now, updated_at: now })
    .eq('driver_id', driverId)
    .eq('status', 'active')

  // Clear previous driver on this vehicle
  if (vehicle.assigned_driver_id && vehicle.assigned_driver_id !== driverId) {
    await supabase
      .from('drivers')
      .update({ trike_plate_number: null, trike_model: null })
      .eq('id', vehicle.assigned_driver_id)
  }

  // Clear driver's previous vehicle
  const { data: prevVehicle } = await supabase
    .from('vehicles')
    .select('id')
    .eq('assigned_driver_id', driverId)
    .maybeSingle()
  if (prevVehicle && String(prevVehicle.id) !== vehicleId) {
    await supabase
      .from('vehicles')
      .update({
        assigned_driver_id: null,
        status: 'available',
        assigned_at: null,
        updated_at: now,
      })
      .eq('id', prevVehicle.id)
  }

  await supabase.from('vehicles').update({
    assigned_driver_id: driverId,
    status: 'assigned',
    assigned_at: now,
    updated_at: now,
  }).eq('id', vehicleId)

  await supabase.from('drivers').update({
    trike_plate_number: vehicle.plate_number,
    trike_model: vehicle.model,
    station: DEFAULT_STATION,
  }).eq('id', driverId)

  await supabase.from('vehicle_assignments').insert({
    vehicle_id: vehicleId,
    driver_id: driverId,
    status: 'active',
    effective_from: now,
    effective_to: effectiveTo,
    assigned_by: opId,
    notes: notes?.trim() || null,
    created_at: now,
    updated_at: now,
  })

  await supabase.from('driver_registration_drafts').upsert({
    driver_id: driverId,
    employment: {
      vehicle_id: vehicleId,
      unit_number: vehicle.unit_number,
      plate_number: vehicle.plate_number,
    },
    updated_at: now,
  })

  await supabase.from('onboarding_timeline').insert({
    driver_id: driverId,
    actor_id: opId,
    action: 'vehicle_assigned',
    summary: `Assigned e-trike unit ${vehicle.unit_number} (${vehicle.plate_number})`,
    metadata: { vehicle_id: vehicleId },
  })

  await logAudit({
    action: 'fleet.assign.active',
    entityType: 'vehicles',
    entityId: vehicleId,
    summary: `Assigned unit ${vehicle.unit_number} to driver`,
    metadata: { driver_id: driverId },
  })
}

export async function unassignVehicleFromDriver(
  driverId: string,
  reason?: string,
): Promise<void> {
  const { data: vehicle } = await supabase
    .from('vehicles')
    .select('*')
    .eq('assigned_driver_id', driverId)
    .maybeSingle()
  if (!vehicle) return

  const now = new Date().toISOString()
  const vehicleId = String(vehicle.id)

  await supabase.from('vehicles').update({
    assigned_driver_id: null,
    status: 'available',
    assigned_at: null,
    updated_at: now,
  }).eq('id', vehicleId)

  await supabase.from('drivers').update({
    trike_plate_number: null,
    trike_model: null,
  }).eq('id', driverId)

  await supabase
    .from('vehicle_assignments')
    .update({ status: 'ended', effective_to: now, updated_at: now })
    .eq('driver_id', driverId)
    .eq('status', 'active')

  await supabase.from('onboarding_timeline').insert({
    driver_id: driverId,
    action: 'vehicle_unassigned',
    summary: reason ?? `Unassigned from unit ${vehicle.unit_number}`,
    metadata: { vehicle_id: vehicleId },
  })
}

export async function activateScheduledAssignments(): Promise<number> {
  const now = new Date().toISOString()
  const { data: scheduled, error } = await supabase
    .from('vehicle_assignments')
    .select('*, vehicles(*)')
    .eq('status', 'scheduled')
    .lte('effective_from', now)
  if (error) throwSupabaseError(error, 'Failed to load scheduled assignments')
  let count = 0
  for (const row of scheduled ?? []) {
    const vehicleRow = row.vehicles as Record<string, unknown> | null
    if (!vehicleRow) continue
    const vehicle = mapVehicle(vehicleRow)
    await activateVehicleAssignment({
      vehicleId: String(row.vehicle_id),
      driverId: String(row.driver_id),
      vehicle,
      notes: row.notes as string | undefined,
      effectiveTo: row.effective_to as string | null,
      opId: row.assigned_by as string | null,
    })
    await supabase
      .from('vehicle_assignments')
      .update({ status: 'ended', updated_at: now })
      .eq('id', row.id)
    count++
  }
  return count
}

export async function listVehicleAssignments(vehicleId: string): Promise<VehicleAssignmentRow[]> {
  const { data, error } = await supabase
    .from('vehicle_assignments')
    .select('*')
    .eq('vehicle_id', vehicleId)
    .order('created_at', { ascending: false })
  if (error) throwSupabaseError(error, 'Failed to load assignments')
  return (data ?? []).map((r) => mapAssignment(r as Record<string, unknown>))
}

export async function listDriverAssignments(driverId: string): Promise<VehicleAssignmentRow[]> {
  const { data, error } = await supabase
    .from('vehicle_assignments')
    .select('*')
    .eq('driver_id', driverId)
    .order('created_at', { ascending: false })
  if (error) throwSupabaseError(error, 'Failed to load assignments')
  return (data ?? []).map((r) => mapAssignment(r as Record<string, unknown>))
}

export async function listDriversForAssign(): Promise<
  { id: string; full_name: string; email: string }[]
> {
  const { data, error } = await supabase
    .from('drivers')
    .select('id, full_name, email, approval_status')
    .in('approval_status', ['pending', 'approved'])
    .order('full_name')
  if (error) throwSupabaseError(error, 'Failed to load drivers')
  return (data ?? []).map((d) => ({
    id: String(d.id),
    full_name: String(d.full_name ?? 'Driver'),
    email: String(d.email ?? ''),
  }))
}

export async function fetchDriverAssignedVehicle(
  driverId: string,
): Promise<FleetVehicle | null> {
  const { data, error } = await supabase
    .from('vehicles')
    .select('*')
    .eq('assigned_driver_id', driverId)
    .maybeSingle()
  if (error) throwSupabaseError(error, 'Failed to load assigned vehicle')
  return data ? mapVehicle(data as Record<string, unknown>) : null
}

export async function listMaintenanceLogs(vehicleId: string): Promise<VehicleMaintenanceLog[]> {
  const { data, error } = await supabase
    .from('vehicle_maintenance_logs')
    .select('*')
    .eq('vehicle_id', vehicleId)
    .order('performed_at', { ascending: false })
  if (error) throwSupabaseError(error, 'Failed to load maintenance logs')
  return (data ?? []).map((r) => mapMaintenance(r as Record<string, unknown>))
}

export async function addMaintenanceLog(
  vehicleId: string,
  input: MaintenanceLogInput,
): Promise<VehicleMaintenanceLog> {
  const opId = await operatorId()
  const performedAt = input.performed_at ?? new Date().toISOString()
  const { data, error } = await supabase
    .from('vehicle_maintenance_logs')
    .insert({
      vehicle_id: vehicleId,
      logged_by: opId,
      maintenance_type: input.maintenance_type,
      description: input.description.trim(),
      cost: input.cost ?? null,
      odometer_km: input.odometer_km ?? null,
      performed_at: performedAt,
      next_due_date: input.next_due_date ?? null,
    })
    .select('*')
    .single()
  if (error) throwSupabaseError(error, 'Failed to log maintenance')

  const vehicleUpdate: Record<string, unknown> = {
    last_maintenance_at: performedAt,
    updated_at: new Date().toISOString(),
  }
  if (input.next_due_date) vehicleUpdate.next_maintenance_due = input.next_due_date
  if (input.maintenance_type !== 'inspection') {
    // optional: set maintenance status during major work — leave assigned drivers as-is for inspection
  }

  await supabase.from('vehicles').update(vehicleUpdate).eq('id', vehicleId)

  await logAudit({
    action: 'fleet.maintenance.log',
    entityType: 'vehicles',
    entityId: vehicleId,
    summary: `Maintenance: ${input.description.slice(0, 80)}`,
  })

  return mapMaintenance(data as Record<string, unknown>)
}

export async function setVehicleMaintenanceMode(
  vehicleId: string,
  inMaintenance: boolean,
): Promise<void> {
  await updateVehicle(vehicleId, {
    status: inMaintenance ? 'maintenance' : 'available',
  })
  if (inMaintenance) {
    const v = await fetchFleetVehicle(vehicleId)
    if (v?.assigned_driver_id) {
      await unassignVehicleFromDriver(
        v.assigned_driver_id,
        'Unit sent to maintenance',
      )
    }
  }
}
