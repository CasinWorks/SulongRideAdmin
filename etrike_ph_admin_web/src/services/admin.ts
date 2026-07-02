import { supabase } from '../lib/supabase'
import {
  DEFAULT_FARE,
  mapDriver,
  mapFareConfig,
  mapFareSchedule,
  mapOperator,
  mapTrip,
} from '../lib/adminMappers'
import {
  auditSummaryDriverApproval,
  auditSummaryFareRates,
  auditSummaryLeaveReview,
  auditSummaryOperatorAction,
  auditSummaryTeamApproval,
  auditSummaryUpdatedFareSchedule,
} from '../lib/auditSummary'
import { driverDisplayName, sameDay, tripDay } from '../lib/format'
import { throwSupabaseError } from '../lib/supabaseError'
import type {
  AttendanceRow,
  DailyTripCount,
  DriverProfile,
  DriverRow,
  EffectiveFare,
  FareConfig,
  FareSchedule,
  FareScheduleType,
  FleetOverview,
  LeaveRow,
  OperatorApprovalStatus,
  OperatorRole,
  OperatorRow,
  TripRow,
} from '../types'
import { fetchAuditLogsForDriver, logAudit } from './audit'

const COMPLETED_TRIP_COLUMNS = [
  'id',
  'driver_id',
  'pickup_address',
  'dropoff_address',
  'fare',
  'status',
  'created_at',
  'completed_at',
  'rating',
  'review_text',
  'complaint_tags',
  'review_acknowledged_at',
].join(', ')

export async function fetchCurrentOperator(): Promise<OperatorRow | null> {
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return null

  const { data, error } = await supabase
    .from('operators')
    .select('*')
    .eq('id', user.id)
    .maybeSingle()

  if (error) throw error
  return data ? mapOperator(data as Record<string, unknown>) : null
}

/** True when this auth user has a row in drivers (driver app account). */
export async function isDriverAccount(): Promise<boolean> {
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return false

  const { data, error } = await supabase
    .from('drivers')
    .select('id')
    .eq('id', user.id)
    .maybeSingle()

  if (error) return false
  return data != null
}

export async function isOperator(): Promise<boolean> {
  const op = await fetchCurrentOperator()
  return op?.approval_status === 'approved'
}

export async function listOperators(status?: OperatorApprovalStatus): Promise<OperatorRow[]> {
  let query = supabase.from('operators').select('*')
  if (status) query = query.eq('approval_status', status)
  const { data, error } = await query.order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []).map((r) => mapOperator(r as Record<string, unknown>))
}

export async function setOperatorApproval(
  operatorId: string,
  status: OperatorApprovalStatus,
): Promise<void> {
  const {
    data: { user },
  } = await supabase.auth.getUser()

  const payload: Record<string, unknown> = { approval_status: status }
  if (status === 'approved') {
    payload.approved_by = user?.id ?? null
    payload.approved_at = new Date().toISOString()
  } else {
    payload.approved_by = null
    payload.approved_at = null
  }

  const { error } = await supabase.from('operators').update(payload).eq('id', operatorId)
  if (error) throw error

  const { data: target } = await supabase
    .from('operators')
    .select('email, full_name')
    .eq('id', operatorId)
    .maybeSingle()

  const targetEmail = target?.email ?? operatorId
  const actionByStatus = {
    approved: 'operator.team.approve',
    revoked: 'operator.team.revoke',
    pending: 'operator.team.mark_pending',
  } as const

  await logAudit({
    action: actionByStatus[status],
    entityType: 'operators',
    entityId: operatorId,
    summary: auditSummaryTeamApproval(targetEmail, status),
    metadata: {
      status,
      email: target?.email,
      full_name: target?.full_name,
    },
  })
}

export async function setOperatorRole(operatorId: string, role: OperatorRole): Promise<void> {
  const { error } = await supabase.from('operators').update({ role }).eq('id', operatorId)
  if (error) throw error

  const { data: target } = await supabase
    .from('operators')
    .select('email, full_name')
    .eq('id', operatorId)
    .maybeSingle()

  await logAudit({
    action: 'operator.role',
    entityType: 'operators',
    entityId: operatorId,
    summary: auditSummaryOperatorAction(
      'Operator role updated',
      target?.email ?? operatorId,
      role,
    ),
    metadata: { role, email: target?.email },
  })
}

export async function updateOperatorSelfName(fullName: string): Promise<void> {
  const { error } = await supabase.rpc('update_operator_self_name', {
    p_full_name: fullName.trim(),
  })
  if (error) throwSupabaseError(error, 'Could not update name')

  await logAudit({
    action: 'operator.profile',
    entityType: 'operators',
    summary: 'Operator updated display name',
    metadata: { full_name: fullName.trim() },
  })
}

export async function updateOperatorNameByAdmin(
  operatorId: string,
  fullName: string,
): Promise<void> {
  const { error } = await supabase.rpc('update_operator_name_by_admin', {
    p_operator_id: operatorId,
    p_full_name: fullName.trim(),
  })
  if (error) throwSupabaseError(error, 'Could not update operator name')

  await logAudit({
    action: 'operator.profile',
    entityType: 'operators',
    entityId: operatorId,
    summary: auditSummaryOperatorAction('Operator name updated', operatorId, fullName.trim()),
    metadata: { full_name: fullName.trim() },
  })
}

export async function updateDriverName(driverId: string, fullName: string): Promise<void> {
  const { error } = await supabase
    .from('drivers')
    .update({ full_name: fullName.trim() })
    .eq('id', driverId)

  if (error) throwSupabaseError(error, 'Could not update driver name')

  await logAudit({
    action: 'driver.profile',
    entityType: 'drivers',
    entityId: driverId,
    summary: auditSummaryOperatorAction('Driver name updated', driverId, fullName.trim()),
    metadata: { full_name: fullName.trim() },
  })
}

export async function countPendingOperators(): Promise<number> {
  const { count, error } = await supabase
    .from('operators')
    .select('*', { count: 'exact', head: true })
    .eq('approval_status', 'pending')

  if (error) return 0
  return count ?? 0
}

export async function listDrivers(approvalStatus?: string): Promise<DriverRow[]> {
  let query = supabase.from('drivers').select('*')
  if (approvalStatus) query = query.eq('approval_status', approvalStatus)
  const { data, error } = await query.order('created_at', { ascending: false })
  if (error) throwSupabaseError(error, 'Failed to load drivers')
  return (data ?? []).map((r) => mapDriver(r as Record<string, unknown>))
}

export async function fetchDriver(driverId: string): Promise<DriverRow | null> {
  const { data } = await supabase
    .from('drivers')
    .select('*')
    .eq('id', driverId)
    .maybeSingle()
  return data ? mapDriver(data as Record<string, unknown>) : null
}

export async function setDriverApproval(
  driverId: string,
  status: string,
): Promise<void> {
  const payload: Record<string, unknown> = { approval_status: status }
  if (status !== 'approved') {
    payload.is_online = false
    payload.is_available = false
  }
  const { error } = await supabase
    .from('drivers')
    .update(payload)
    .eq('id', driverId)
  if (error) throw error
  await logAudit({
    action: 'driver.approval',
    entityType: 'drivers',
    entityId: driverId,
    summary: auditSummaryDriverApproval(status),
    metadata: { status },
  })
}

export { DEFAULT_FARE } from '../lib/adminMappers'

function hardcodedDefaultEffectiveFare(): EffectiveFare {
  return {
    id: '',
    base_fare: DEFAULT_FARE.baseFare,
    per_km_rate: DEFAULT_FARE.perKmRate,
    minimum_fare: DEFAULT_FARE.minimumFare,
    currency: DEFAULT_FARE.currency,
    is_active: true,
    updated_at: null,
    fare_source: 'default',
    schedule_id: null,
    schedule_label: null,
  }
}

/** Default fare from fare_config (used when no schedule is active). */
export async function fetchActiveFare(): Promise<FareConfig | null> {
  const { data, error } = await supabase
    .from('fare_config')
    .select('*')
    .eq('is_active', true)
    .order('updated_at', { ascending: false })
    .limit(1)
    .maybeSingle()
  if (error) throw error
  if (!data) return null
  return mapFareConfig(data as Record<string, unknown>)
}

function mapEffectiveFare(row: Record<string, unknown>): EffectiveFare {
  const base = mapFareConfig(row)
  return {
    ...base,
    fare_source: (row.fare_source as EffectiveFare['fare_source']) ?? 'default',
    schedule_id: (row.schedule_id as string) ?? null,
    schedule_label: (row.schedule_label as string) ?? null,
  }
}

/** Resolved fare at now() — active schedule if in window, else default. */
export async function fetchEffectiveFare(): Promise<EffectiveFare> {
  const { data, error } = await supabase
    .from('effective_fare_config')
    .select('*')
    .maybeSingle()

  if (!error && data) {
    return mapEffectiveFare(data as Record<string, unknown>)
  }

  const fallback = await fetchActiveFare()
  if (fallback) {
    return { ...fallback, fare_source: 'default', schedule_id: null, schedule_label: null }
  }

  return hardcodedDefaultEffectiveFare()
}

export async function listFareSchedules(): Promise<FareSchedule[]> {
  const { data, error } = await supabase
    .from('fare_schedules')
    .select('*')
    .order('starts_at', { ascending: false })

  if (error) throwSupabaseError(error, 'Failed to load fare schedules')
  return (data ?? []).map((r) => mapFareSchedule(r as Record<string, unknown>))
}

export async function createFareSchedule(params: {
  label: string
  scheduleType: FareScheduleType
  baseFare: number
  perKmRate: number
  minimumFare: number
  startsAt: string
  endsAt: string | null
}): Promise<FareSchedule> {
  const {
    data: { user },
  } = await supabase.auth.getUser()

  const { data, error } = await supabase
    .from('fare_schedules')
    .insert({
      label: params.label,
      schedule_type: params.scheduleType,
      base_fare: params.baseFare,
      per_km_rate: params.perKmRate,
      minimum_fare: params.minimumFare,
      starts_at: params.startsAt,
      ends_at: params.endsAt,
      created_by: user?.id ?? null,
    })
    .select('*')
    .single()

  if (error) throwSupabaseError(error, 'Failed to create fare schedule')
  const schedule = mapFareSchedule(data as Record<string, unknown>)
  await logAudit({
    action: 'fare.schedule.create',
    entityType: 'fare_schedules',
    entityId: schedule.id,
    summary: auditSummaryUpdatedFareSchedule(schedule.label),
    metadata: {
      schedule_type: schedule.schedule_type,
      base_fare: schedule.base_fare,
      starts_at: schedule.starts_at,
      ends_at: schedule.ends_at,
    },
  })
  return schedule
}

export async function updateFareSchedule(
  id: string,
  params: {
    label: string
    scheduleType: FareScheduleType
    baseFare: number
    perKmRate: number
    minimumFare: number
    startsAt: string
    endsAt: string | null
    isActive: boolean
  },
): Promise<void> {
  const { error } = await supabase
    .from('fare_schedules')
    .update({
      label: params.label,
      schedule_type: params.scheduleType,
      base_fare: params.baseFare,
      per_km_rate: params.perKmRate,
      minimum_fare: params.minimumFare,
      starts_at: params.startsAt,
      ends_at: params.endsAt,
      is_active: params.isActive,
      updated_at: new Date().toISOString(),
    })
    .eq('id', id)

  if (error) throwSupabaseError(error, 'Failed to update fare schedule')
  await logAudit({
    action: 'fare.schedule.update',
    entityType: 'fare_schedules',
    entityId: id,
    summary: auditSummaryUpdatedFareSchedule(params.label),
    metadata: params,
  })
}

export async function deactivateFareSchedule(id: string): Promise<void> {
  const { error } = await supabase
    .from('fare_schedules')
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .eq('id', id)

  if (error) throwSupabaseError(error, 'Failed to deactivate fare schedule')
  await logAudit({
    action: 'fare.schedule.deactivate',
    entityType: 'fare_schedules',
    entityId: id,
    summary: 'Deactivated scheduled fare',
  })
}

export async function initializeDefaultFare(params?: {
  baseFare?: number
  perKmRate?: number
  minimumFare?: number
}): Promise<FareConfig> {
  const baseFare = params?.baseFare ?? DEFAULT_FARE.baseFare
  const perKmRate = params?.perKmRate ?? DEFAULT_FARE.perKmRate
  const minimumFare = params?.minimumFare ?? DEFAULT_FARE.minimumFare

  const { data, error } = await supabase
    .from('fare_config')
    .insert({
      base_fare: baseFare,
      per_km_rate: perKmRate,
      minimum_fare: minimumFare,
      currency: DEFAULT_FARE.currency,
      is_active: true,
    })
    .select('*')
    .single()

  if (error) throw error
  const config = mapFareConfig(data as Record<string, unknown>)
  await logAudit({
    action: 'fare.initialize',
    entityType: 'fare_config',
    entityId: config.id,
    summary: auditSummaryFareRates('Default fare initialized', {
      base: config.base_fare,
      perKm: config.per_km_rate,
      minimum: config.minimum_fare,
    }),
    metadata: {
      base_fare: config.base_fare,
      per_km_rate: config.per_km_rate,
      minimum_fare: config.minimum_fare,
    },
  })
  return config
}

export async function updateActiveFare(params: {
  id: string
  baseFare: number
  perKmRate: number
  minimumFare: number
}): Promise<void> {
  const { error } = await supabase
    .from('fare_config')
    .update({
      base_fare: params.baseFare,
      per_km_rate: params.perKmRate,
      minimum_fare: params.minimumFare,
      updated_at: new Date().toISOString(),
    })
    .eq('id', params.id)
  if (error) throw error
  await logAudit({
    action: 'fare.update',
    entityType: 'fare_config',
    entityId: params.id,
    summary: auditSummaryFareRates('Default fare updated', {
      base: params.baseFare,
      perKm: params.perKmRate,
      minimum: params.minimumFare,
    }),
    metadata: {
      base_fare: params.baseFare,
      per_km_rate: params.perKmRate,
      minimum_fare: params.minimumFare,
    },
  })
}

export async function listLeaveRequests(status?: string): Promise<LeaveRow[]> {
  let query = supabase
    .from('leave_requests')
    .select('*, drivers(full_name, email)')
  if (status) query = query.eq('status', status)
  const { data, error } = await query.order('created_at', { ascending: false })
  if (error) return []
  return (data ?? []) as LeaveRow[]
}

export async function reviewLeaveRequest(
  id: string,
  status: 'approved' | 'rejected',
): Promise<void> {
  const { error } = await supabase
    .from('leave_requests')
    .update({
      status,
      reviewed_at: new Date().toISOString(),
    })
    .eq('id', id)
  if (error) throw error
  await logAudit({
    action: 'leave.review',
    entityType: 'leave_requests',
    entityId: id,
    summary: auditSummaryLeaveReview(status),
    metadata: { status },
  })
}

export async function listAttendance(limit = 50): Promise<AttendanceRow[]> {
  const { data, error } = await supabase
    .from('driver_attendance')
    .select('*, drivers(full_name, email)')
    .order('clock_in', { ascending: false })
    .limit(limit)
  if (error) return []
  return (data ?? []) as AttendanceRow[]
}

async function fetchCompletedTrips(): Promise<TripRow[]> {
  const { data, error } = await supabase
    .from('trips')
    .select(COMPLETED_TRIP_COLUMNS)
    .eq('status', 'completed')
    .order('created_at', { ascending: false })

  if (error) throw error
  return (data ?? []).map((r) => mapTrip(r as unknown as Record<string, unknown>))
}

export async function acknowledgeTripReview(tripId: string): Promise<void> {
  const { error } = await supabase
    .from('trips')
    .update({ review_acknowledged_at: new Date().toISOString() })
    .eq('id', tripId)
  if (error) throw error
  await logAudit({
    action: 'trip.review_acknowledge',
    entityType: 'trips',
    entityId: tripId,
    summary: 'Trip review acknowledged',
  })
}

export async function fetchFleetOverview(): Promise<FleetOverview> {
  const now = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const yesterday = new Date(today)
  yesterday.setDate(yesterday.getDate() - 1)

  const drivers = await listDrivers()
  const approved = drivers.filter((d) => d.approval_status === 'approved')
  const pending = drivers.filter((d) => d.approval_status === 'pending')
  const trips = await fetchCompletedTrips()

  const tripsToday = trips.filter((t) => sameDay(tripDay(t), today)).length
  const tripsYesterday = trips.filter((t) =>
    sameDay(tripDay(t), yesterday),
  ).length
  const faresToday = trips
    .filter((t) => sameDay(tripDay(t), today))
    .reduce((s, t) => s + t.fare, 0)

  const tripsLast7Days: DailyTripCount[] = Array.from({ length: 7 }, (_, i) => {
    const day = new Date(today)
    day.setDate(day.getDate() - (6 - i))
    const count = trips.filter((t) => sameDay(tripDay(t), day)).length
    return {
      date: day.toISOString(),
      count,
      label: day.toLocaleDateString('en-PH', { weekday: 'short' }),
    }
  })

  const attendance = await listAttendance(200)
  const onDuty = attendance.filter((a) => !a.clock_out).length

  let onLeave = 0
  try {
    const leaves = await listLeaveRequests('approved')
    for (const l of leaves) {
      const start = new Date(l.start_date)
      const end = new Date(l.end_date)
      if (today >= start && today <= end) onLeave++
    }
  } catch {
    /* optional table */
  }

  const offDuty = Math.max(0, approved.length - onDuty - onLeave)

  const weekStart = new Date(today)
  weekStart.setDate(weekStart.getDate() - 6)
  const tripsByDriver = new Map<string, number>()
  for (const t of trips) {
    if (!t.driver_id || tripDay(t) < weekStart) continue
    tripsByDriver.set(t.driver_id, (tripsByDriver.get(t.driver_id) ?? 0) + 1)
  }

  const topDriversThisWeek = [...tripsByDriver.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([id, tripCount]) => {
      const d = drivers.find((x) => x.id === id)
      return { id, name: d ? driverDisplayName(d) : 'Driver', trips: tripCount }
    })

  const flaggedItems: FleetOverview['flaggedItems'] = []
  if (pending.length > 0) {
    flaggedItems.push({
      title: `${pending.length} drivers pending approval`,
      subtitle: 'New registrations waiting for operator review',
      borderColor: '#f59e0b',
      tab: 'pending',
    })
  }

  try {
    const pendingLeave = await listLeaveRequests('pending')
    if (pendingLeave.length > 0) {
      flaggedItems.push({
        title: `${pendingLeave.length} unapproved leave requests`,
        subtitle: 'VL and SL requests submitted recently',
        borderColor: '#f59e0b',
        tab: 'leave',
      })
    }
  } catch {
    /* optional */
  }

  try {
    const pendingOperators = await countPendingOperators()
    if (pendingOperators > 0) {
      flaggedItems.push({
        title: `${pendingOperators} operator${pendingOperators === 1 ? '' : 's'} pending approval`,
        subtitle: 'New admin sign-ins waiting for super admin review',
        borderColor: '#f59e0b',
        tab: 'team',
      })
    }
  } catch {
    /* optional */
  }

  return {
    activeDrivers: approved.length,
    pendingApproval: pending.length,
    tripsToday,
    tripsYesterday,
    faresToday,
    avgFareToday: tripsToday > 0 ? faresToday / tripsToday : 0,
    driversOnDuty: onDuty,
    tripsLast7Days,
    driverStatus: {
      onDuty,
      offDuty,
      onLeave,
      pending: pending.length,
    },
    flaggedItems,
    topDriversThisWeek,
  }
}

export async function fetchDriverProfile(driverId: string): Promise<DriverProfile> {
  const driver = await fetchDriver(driverId)
  const trips = (await fetchCompletedTrips()).filter(
    (t) => t.driver_id === driverId,
  )
  const rated = trips.filter((t) => t.rating != null)
  const overall =
    rated.length > 0
      ? rated.reduce((s, t) => s + (t.rating ?? 0), 0) / rated.length
      : 0

  const now = new Date()
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1)
  const monthTrips = trips.filter((t) => tripDay(t) >= monthStart)

  const logs = await fetchAuditLogsForDriver(driverId)

  let statusLabel = 'Active'
  if (driver?.approval_status === 'rejected') statusLabel = 'Revoked'
  else if (driver?.approval_status === 'pending') statusLabel = 'Pending'

  return {
    id: driverId,
    fullName: driver ? driverDisplayName(driver) : 'Driver',
    email: driver?.email ?? '—',
    phone: driver?.phone ?? '—',
    plate: driver?.trike_plate_number ?? '—',
    statusLabel,
    approvalStatus: driver?.approval_status ?? 'pending',
    overallRating: overall,
    totalTrips: trips.length,
    tripsThisMonth: monthTrips.length,
    totalEarnings: trips.reduce((s, t) => s + t.fare, 0),
    recentTrips: trips.slice(0, 10),
    lowRatingReviews: trips
      .filter((t) => t.rating != null && t.rating <= 3)
      .slice(0, 5),
    activityLog: logs.map((l) => ({
      date: l.created_at,
      action: l.summary,
    })),
  }
}

export async function fetchWeeklyTripsByDriver(): Promise<Record<string, number>> {
  const trips = await fetchCompletedTrips()
  const weekStart = new Date()
  weekStart.setDate(weekStart.getDate() - 6)
  weekStart.setHours(0, 0, 0, 0)
  const map: Record<string, number> = {}
  for (const t of trips) {
    if (!t.driver_id || tripDay(t) < weekStart) continue
    map[t.driver_id] = (map[t.driver_id] ?? 0) + 1
  }
  return map
}
