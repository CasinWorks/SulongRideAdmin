import { supabase } from '../lib/supabase'
import { throwSupabaseError } from '../lib/supabaseError'
import {
  buildDriverSchedule,
  buildRosterForDate,
  countShiftsForMonth,
} from '../lib/rosterLogic'
import { shiftToUpdatePayload, type ShiftConfig } from '../lib/shiftConfig'
import { listDrivers } from './admin'
import { logAudit } from './audit'
import type { AttendanceRow, LeaveRow } from '../types'
import type { DayRosterSummary, DriverScheduleDay } from '../types/roster'

async function fetchAllAttendance(): Promise<AttendanceRow[]> {
  const { data, error } = await supabase
    .from('driver_attendance')
    .select('*, drivers(full_name, email)')
    .order('clock_in', { ascending: false })
    .limit(500)
  if (error) return []
  return (data ?? []) as AttendanceRow[]
}

async function fetchApprovedLeave(): Promise<LeaveRow[]> {
  const { data, error } = await supabase
    .from('leave_requests')
    .select('*, drivers(full_name, email)')
    .eq('status', 'approved')
  if (error) return []
  return (data ?? []) as LeaveRow[]
}

export async function fetchRosterForDate(day: Date): Promise<DayRosterSummary> {
  const [drivers, attendance, leaves] = await Promise.all([
    listDrivers(),
    fetchAllAttendance(),
    fetchApprovedLeave(),
  ])
  return buildRosterForDate(day, drivers, attendance, leaves)
}

export async function fetchShiftCountsForMonth(month: Date): Promise<Record<string, number>> {
  const attendance = await fetchAllAttendance()
  return countShiftsForMonth(month, attendance)
}

export async function fetchDriverSchedule(
  driverId: string,
  month: Date,
): Promise<DriverScheduleDay[]> {
  const [drivers, attendance, leaves] = await Promise.all([
    listDrivers(),
    fetchAllAttendance(),
    fetchApprovedLeave(),
  ])
  const driver = drivers.find((d) => d.id === driverId) ?? null
  return buildDriverSchedule(driverId, month, driver, attendance, leaves)
}

export async function updateDriverShift(
  driverId: string,
  config: ShiftConfig,
  driverName?: string,
): Promise<void> {
  const payload = shiftToUpdatePayload(config)
  const { error } = await supabase.from('drivers').update(payload).eq('id', driverId)
  if (error) throwSupabaseError(error, 'Failed to save work schedule')
  await logAudit({
    action: 'driver.shift_update',
    entityType: 'drivers',
    entityId: driverId,
    summary: `Work schedule updated${driverName ? ` — ${driverName}` : ''}`,
    metadata: payload,
  })
}
