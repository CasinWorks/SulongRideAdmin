import { DEFAULT_STATION } from './onboardingConstants'
import type { DriverRow } from '../types'
import type { ShiftConfigInput } from '../types/roster'

export const WEEKDAY_LABELS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'] as const

export const PRESET_STATIONS = [
  'Carmona Central',
  'Vista Mall Carmona',
  'Southwoods Hub',
  'Carmona Public Market',
] as const

export type ShiftConfig = {
  days: Set<number>
  startHour: number
  startMinute: number
  endHour: number
  endMinute: number
  station: string
  employmentType: string
}

export const SHIFT_PRESETS: Record<string, Omit<ShiftConfig, 'station' | 'employmentType'>> = {
  'Morning (6 AM – 2 PM)': {
    days: new Set([1, 2, 3, 4, 5, 6]),
    startHour: 6,
    startMinute: 0,
    endHour: 14,
    endMinute: 0,
  },
  'Afternoon (2 PM – 10 PM)': {
    days: new Set([1, 2, 3, 4, 5, 6]),
    startHour: 14,
    startMinute: 0,
    endHour: 22,
    endMinute: 0,
  },
  'Mon–Fri day': {
    days: new Set([1, 2, 3, 4, 5]),
    startHour: 6,
    startMinute: 0,
    endHour: 14,
    endMinute: 0,
  },
}

export function parseTime(raw: string | null | undefined): { hour: number; minute: number } {
  const parts = (raw ?? '06:00:00').split(':')
  return {
    hour: Number.parseInt(parts[0] ?? '6', 10) || 6,
    minute: Number.parseInt(parts[1] ?? '0', 10) || 0,
  }
}

export function parseShiftDays(raw: unknown): Set<number> {
  if (Array.isArray(raw) && raw.length > 0) {
    return new Set(raw.map((e) => Number(e)).filter((n) => n >= 1 && n <= 7))
  }
  return new Set([1, 2, 3, 4, 5, 6])
}

export function shiftConfigFromDriver(driver: Pick<DriverRow, 'shift_days' | 'shift_start' | 'shift_end' | 'station' | 'employment_type'>): ShiftConfig {
  const start = parseTime(driver.shift_start)
  const end = parseTime(driver.shift_end)
  return {
    days: parseShiftDays(driver.shift_days),
    startHour: start.hour,
    startMinute: start.minute,
    endHour: end.hour,
    endMinute: end.minute,
    station: driver.station || DEFAULT_STATION,
    employmentType: driver.employment_type || 'contractual',
  }
}

export function employmentLabel(type: string): string {
  return type === 'permanent' ? 'Permanent' : 'Contractual'
}

export function formatTime(hour: number, minute: number): string {
  const period = hour >= 12 ? 'PM' : 'AM'
  const h12 = hour % 12 === 0 ? 12 : hour % 12
  return `${h12}:${String(minute).padStart(2, '0')} ${period}`
}

function formatDayRange(sorted: number[]): string {
  if (sorted.length === 0) return 'No days'
  if (sorted.length === 7) return 'Mon–Sun'
  if (sorted.length === 6 && !sorted.includes(7)) return 'Mon–Sat'
  if (sorted.length === 5 && sorted.every((d) => d <= 5)) return 'Mon–Fri'
  return sorted.map((d) => WEEKDAY_LABELS[d - 1]).join(', ')
}

export function shiftDisplayString(config: ShiftConfig): string {
  const sorted = [...config.days].sort((a, b) => a - b)
  return `${formatDayRange(sorted)} · ${formatTime(config.startHour, config.startMinute)} – ${formatTime(config.endHour, config.endMinute)}`
}

export function shiftWorksOn(config: ShiftConfig, date: Date): boolean {
  const iso = date.getDay() === 0 ? 7 : date.getDay()
  return config.days.has(iso)
}

export function timeToPg(hour: number, minute: number): string {
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00`
}

export function shiftToUpdatePayload(config: ShiftConfig): Record<string, unknown> {
  const sortedDays = [...config.days].sort((a, b) => a - b)
  return {
    shift_days: sortedDays,
    shift_start: timeToPg(config.startHour, config.startMinute),
    shift_end: timeToPg(config.endHour, config.endMinute),
    shift_schedule: shiftDisplayString(config),
    station: config.station.trim() || DEFAULT_STATION,
    employment_type: config.employmentType,
  }
}

export function shiftFromInput(input: ShiftConfigInput): ShiftConfig {
  const start = parseTime(input.start)
  const end = parseTime(input.end)
  return {
    days: new Set(input.days),
    startHour: start.hour,
    startMinute: start.minute,
    endHour: end.hour,
    endMinute: end.minute,
    station: input.station.trim() || DEFAULT_STATION,
    employmentType: input.employmentType || 'contractual',
  }
}
