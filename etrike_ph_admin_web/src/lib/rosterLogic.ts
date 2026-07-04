import type { AttendanceRow, DriverRow, LeaveRow } from '../types'
import type {
  AttendanceBlock,
  DayRosterSummary,
  DriverDayStatus,
  DriverRosterEntry,
  DriverScheduleDay,
} from '../types/roster'
import { employmentLabel, shiftConfigFromDriver, shiftWorksOn } from './shiftConfig'

export function dayOnly(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate())
}

export function dayKey(d: Date): string {
  const x = dayOnly(d)
  const m = String(x.getMonth() + 1).padStart(2, '0')
  const day = String(x.getDate()).padStart(2, '0')
  return `${x.getFullYear()}-${m}-${day}`
}

export function parseDayKey(key: string): Date {
  const [y, m, d] = key.split('-').map(Number)
  return new Date(y, m - 1, d)
}

export function dateInRange(day: Date, startIso: string, endIso: string): boolean {
  const d = dayOnly(day).getTime()
  const start = dayOnly(new Date(startIso)).getTime()
  const end = dayOnly(new Date(endIso)).getTime()
  return d >= start && d <= end
}

export function wasOnShift(attendance: AttendanceRow, day: Date): boolean {
  const d = dayOnly(day)
  const inD = dayOnly(new Date(attendance.clock_in))
  if (inD.getTime() > d.getTime()) return false
  if (!attendance.clock_out) return inD.getTime() <= d.getTime()
  const outD = dayOnly(new Date(attendance.clock_out))
  return outD.getTime() >= d.getTime()
}

const STATUS_SORT: Record<DriverDayStatus, number> = {
  on_shift: 0,
  online: 1,
  off_duty: 2,
  on_leave_vl: 3,
  on_leave_sl: 4,
  pending: 5,
  revoked: 6,
}

export function rosterStatusLabel(status: DriverDayStatus): string {
  return (
    {
      on_leave_vl: 'On leave (VL)',
      on_leave_sl: 'On leave (SL)',
      on_shift: 'On shift',
      online: 'Online',
      off_duty: 'Off duty',
      pending: 'Pending approval',
      revoked: 'Revoked',
    }[status] ?? status
  )
}

export function rosterStatusColor(status: DriverDayStatus): string {
  return (
    {
      on_shift: '#059669',
      online: '#2563EB',
      off_duty: '#9CA3AF',
      on_leave_vl: '#D97706',
      on_leave_sl: '#EA580C',
      pending: '#D97706',
      revoked: '#DC2626',
    }[status] ?? '#6B7280'
  )
}

export function buildRosterForDate(
  day: Date,
  drivers: DriverRow[],
  attendance: AttendanceRow[],
  leaves: LeaveRow[],
): DayRosterSummary {
  const d = dayOnly(day)
  const isToday = dayKey(d) === dayKey(new Date())
  const entries: DriverRosterEntry[] = []

  for (const driver of drivers) {
    const fullName = driver.full_name.trim() || driver.email

    if (driver.approval_status !== 'approved') {
      entries.push({
        driverId: driver.id,
        fullName,
        email: driver.email,
        station: driver.station,
        shiftSchedule: driver.shift_schedule,
        employmentType: employmentLabel(driver.employment_type),
        status: driver.approval_status === 'pending' ? 'pending' : 'revoked',
        isOnline: false,
        isOnShift: false,
        leaveType: null,
        clockIn: null,
        clockOut: null,
        phone: driver.phone,
        plate: driver.trike_plate_number,
      })
      continue
    }

    const leaveToday = leaves.find(
      (l) => l.driver_id === driver.id && dateInRange(d, l.start_date, l.end_date),
    )

    const dayAttendance = attendance.filter(
      (a) => a.driver_id === driver.id && wasOnShift(a, d),
    )
    const onShift = leaveToday == null && dayAttendance.length > 0
    const openNow = isToday && dayAttendance.some((a) => !a.clock_out)
    const shift = shiftConfigFromDriver(driver)
    const scheduledDay = shiftWorksOn(shift, d)

    let status: DriverDayStatus
    if (leaveToday) {
      status = leaveToday.leave_type === 'SL' ? 'on_leave_sl' : 'on_leave_vl'
    } else if (onShift) {
      status = 'on_shift'
    } else if (!scheduledDay) {
      status = 'off_duty'
    } else if (isToday && driver.is_online) {
      status = 'online'
    } else {
      status = 'off_duty'
    }

    const primary = dayAttendance[0]

    entries.push({
      driverId: driver.id,
      fullName,
      email: driver.email,
      station: driver.station,
      shiftSchedule: scheduledDay
        ? driver.shift_schedule
        : `${driver.shift_schedule} (off today)`,
      employmentType: employmentLabel(driver.employment_type),
      status,
      isOnline: isToday && driver.is_online,
      isOnShift: onShift && openNow,
      leaveType: leaveToday?.leave_type ?? null,
      clockIn: primary?.clock_in ?? null,
      clockOut: primary?.clock_out ?? null,
      phone: driver.phone,
      plate: driver.trike_plate_number,
    })
  }

  entries.sort((a, b) => {
    const c = STATUS_SORT[a.status] - STATUS_SORT[b.status]
    if (c !== 0) return c
    return a.fullName.localeCompare(b.fullName)
  })

  return { date: dayKey(d), entries }
}

export function countShiftsForMonth(
  month: Date,
  attendance: AttendanceRow[],
): Record<string, number> {
  const first = new Date(month.getFullYear(), month.getMonth(), 1)
  const last = new Date(month.getFullYear(), month.getMonth() + 1, 0)
  const counts: Record<string, number> = {}

  for (let d = new Date(first); d <= last; d.setDate(d.getDate() + 1)) {
    const day = dayOnly(new Date(d))
    const ids = new Set(
      attendance.filter((a) => wasOnShift(a, day)).map((a) => a.driver_id),
    )
    if (ids.size > 0) counts[dayKey(day)] = ids.size
  }
  return counts
}

export function buildDriverSchedule(
  driverId: string,
  month: Date,
  driver: DriverRow | null,
  attendance: AttendanceRow[],
  leaves: LeaveRow[],
): DriverScheduleDay[] {
  if (!driver) return []

  const shift = shiftConfigFromDriver(driver)
  const first = new Date(month.getFullYear(), month.getMonth(), 1)
  const last = new Date(month.getFullYear(), month.getMonth() + 1, 0)
  const todayKey = dayKey(new Date())
  const days: DriverScheduleDay[] = []

  for (let d = new Date(first); d <= last; d.setDate(d.getDate() + 1)) {
    const day = dayOnly(new Date(d))
    const key = dayKey(day)
    const blocks: AttendanceBlock[] = attendance
      .filter((a) => a.driver_id === driverId && wasOnShift(a, day))
      .map((a) => ({ clockIn: a.clock_in, clockOut: a.clock_out }))

    const leave = leaves.find(
      (l) => l.driver_id === driverId && dateInRange(day, l.start_date, l.end_date),
    )

    let status: DriverDayStatus
    if (leave) {
      status = leave.leave_type === 'SL' ? 'on_leave_sl' : 'on_leave_vl'
    } else if (!shiftWorksOn(shift, day)) {
      status = 'off_duty'
    } else if (blocks.length > 0) {
      status = 'on_shift'
    } else if (key === todayKey && driver.is_online) {
      status = 'online'
    } else {
      status = 'off_duty'
    }

    days.push({
      date: key,
      status,
      leaveType: leave?.leave_type ?? null,
      attendanceBlocks: blocks,
    })
  }

  return days
}

export function rosterSummaryCounts(summary: DayRosterSummary): {
  onShift: number
  online: number
  onLeave: number
  offDuty: number
} {
  return {
    onShift: summary.entries.filter((e) => e.status === 'on_shift').length,
    online: summary.entries.filter((e) => e.isOnline).length,
    onLeave: summary.entries.filter(
      (e) => e.status === 'on_leave_vl' || e.status === 'on_leave_sl',
    ).length,
    offDuty: summary.entries.filter((e) => e.status === 'off_duty').length,
  }
}
