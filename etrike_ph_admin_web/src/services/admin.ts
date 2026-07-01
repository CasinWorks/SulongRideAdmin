import { supabase } from '../lib/supabase'
import { driverDisplayName, sameDay, tripDay } from '../lib/format'
import type {
  AttendanceRow,
  DailyTripCount,
  DriverProfile,
  DriverRow,
  FareConfig,
  FleetOverview,
  LeaveRow,
  TripRow,
} from '../types'
import { fetchAuditLogsForDriver, logAudit } from './audit'

function mapDriver(row: Record<string, unknown>): DriverRow {
  return {
    id: row.id as string,
    full_name: (row.full_name as string) ?? '',
    email: (row.email as string) ?? '',
    phone: (row.phone as string) ?? null,
    trike_plate_number: (row.trike_plate_number as string) ?? null,
    trike_model: (row.trike_model as string) ?? null,
    approval_status: (row.approval_status as string) ?? 'pending',
    created_at: (row.created_at as string) ?? null,
    is_online: (row.is_online as boolean) ?? false,
    is_available: (row.is_available as boolean) ?? false,
    employment_type: (row.employment_type as string) ?? 'contractual',
    station: (row.station as string) ?? 'Carmona Central',
    shift_schedule: (row.shift_schedule as string) ?? '—',
    emergency_contact: (row.emergency_contact as string) ?? '',
    start_date: (row.start_date as string) ?? null,
  }
}

function mapTrip(row: Record<string, unknown>): TripRow {
  const tags = row.complaint_tags
  return {
    id: row.id as string,
    driver_id: (row.driver_id as string) ?? null,
    pickup_address: (row.pickup_address as string) ?? '',
    dropoff_address: (row.dropoff_address as string) ?? '',
    fare: Number(row.fare ?? 0),
    status: (row.status as string) ?? '',
    created_at: row.created_at as string,
    completed_at: (row.completed_at as string) ?? null,
    rating: row.rating != null ? Number(row.rating) : null,
    review_text: (row.review_text as string) ?? null,
    complaint_tags: Array.isArray(tags) ? tags.map(String) : null,
    review_acknowledged_at: (row.review_acknowledged_at as string) ?? null,
  }
}

export async function isOperator(): Promise<boolean> {
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return false

  const { data } = await supabase
    .from('operators')
    .select('id')
    .eq('id', user.id)
    .maybeSingle()

  return data != null
}

export async function listDrivers(approvalStatus?: string): Promise<DriverRow[]> {
  let query = supabase.from('drivers').select('*')
  if (approvalStatus) query = query.eq('approval_status', approvalStatus)
  const { data, error } = await query.order('created_at', { ascending: false })
  if (error) throw error
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
    summary: `Driver approval set to ${status}`,
    metadata: { status },
  })
}

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
  const row = data as Record<string, unknown>
  return {
    id: row.id as string,
    base_fare: Number(row.base_fare ?? 40),
    per_km_rate: Number(row.per_km_rate ?? 0),
    minimum_fare: Number(row.minimum_fare ?? 40),
    currency: (row.currency as string) ?? 'PHP',
    is_active: (row.is_active as boolean) ?? true,
    updated_at: (row.updated_at as string) ?? null,
  }
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
    summary: `Fare updated — base ₱${params.baseFare}, per km ₱${params.perKmRate}, min ₱${params.minimumFare}`,
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
    summary: `Leave request ${status}`,
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
    .select(
      'id, driver_id, pickup_address, dropoff_address, fare, status, created_at, completed_at, rating, review_text, complaint_tags, review_acknowledged_at',
    )
    .eq('status', 'completed')
    .order('created_at', { ascending: false })

  if (error) throw error
  return (data ?? []).map((r) => mapTrip(r as Record<string, unknown>))
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
