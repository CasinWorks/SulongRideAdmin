import type { FareSchedule } from '../types'

export type ScheduleStatus = 'upcoming' | 'active' | 'ended' | 'inactive'

const pad2 = (n: number) => String(n).padStart(2, '0')

export function scheduleStatus(s: FareSchedule): ScheduleStatus {
  if (!s.is_active) return 'inactive'
  const now = Date.now()
  const start = new Date(s.starts_at).getTime()
  const end = s.ends_at ? new Date(s.ends_at).getTime() : null
  if (start > now) return 'upcoming'
  if (end != null && end < now) return 'ended'
  return 'active'
}

export function statusBadge(status: ScheduleStatus): string {
  switch (status) {
    case 'active':
      return 'bg-green-100 text-green-800'
    case 'upcoming':
      return 'bg-blue-100 text-blue-800'
    case 'ended':
      return 'bg-gray-100 text-gray-600'
    case 'inactive':
      return 'bg-red-100 text-red-700'
  }
}

export function defaultDatetimeLocal(date = new Date()): string {
  const y = date.getFullYear()
  const mo = pad2(date.getMonth() + 1)
  const d = pad2(date.getDate())
  const h = pad2(date.getHours())
  const mi = pad2(date.getMinutes())
  return `${y}-${mo}-${d}T${h}:${mi}`
}

export function toDatetimeLocal(iso: string | null): string {
  if (!iso) return ''
  return defaultDatetimeLocal(new Date(iso))
}

export function parseDatetimeLocal(value: string): Date | null {
  const trimmed = value.trim()
  if (!trimmed) return null
  const normalized = trimmed.includes('T') ? trimmed : trimmed.replace(' ', 'T')
  const [datePart, timePart] = normalized.split('T')
  if (!datePart || !timePart) return null
  const [year, month, day] = datePart.split('-').map(Number)
  const [hour, minute] = timePart.split(':').map(Number)
  if ([year, month, day, hour, minute].some((n) => Number.isNaN(n))) return null
  const parsed = new Date(year, month - 1, day, hour, minute, 0, 0)
  return Number.isNaN(parsed.getTime()) ? null : parsed
}
