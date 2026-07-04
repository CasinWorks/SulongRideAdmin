export type DriverDayStatus =
  | 'on_leave_vl'
  | 'on_leave_sl'
  | 'on_shift'
  | 'online'
  | 'off_duty'
  | 'pending'
  | 'revoked'

export type DriverRosterEntry = {
  driverId: string
  fullName: string
  email: string
  station: string
  shiftSchedule: string
  employmentType: string
  status: DriverDayStatus
  isOnline: boolean
  isOnShift: boolean
  leaveType: string | null
  clockIn: string | null
  clockOut: string | null
  phone: string | null
  plate: string | null
}

export type DayRosterSummary = {
  date: string
  entries: DriverRosterEntry[]
}

export type AttendanceBlock = {
  clockIn: string
  clockOut: string | null
}

export type DriverScheduleDay = {
  date: string
  status: DriverDayStatus
  leaveType: string | null
  attendanceBlocks: AttendanceBlock[]
}

export type ShiftConfigInput = {
  days: number[]
  start: string
  end: string
  station: string
  employmentType: string
}
