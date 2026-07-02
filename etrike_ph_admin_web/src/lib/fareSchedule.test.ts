import { describe, expect, it } from 'vitest'
import type { FareSchedule } from '../types'
import {
  defaultDatetimeLocal,
  parseDatetimeLocal,
  scheduleStatus,
  statusBadge,
  toDatetimeLocal,
} from './fareSchedule'

function schedule(overrides: Partial<FareSchedule> = {}): FareSchedule {
  return {
    id: '1',
    label: 'Test',
    schedule_type: 'discount',
    base_fare: 40,
    per_km_rate: 12,
    minimum_fare: 35,
    currency: 'PHP',
    starts_at: new Date().toISOString(),
    ends_at: null,
    is_active: true,
    created_at: '',
    updated_at: '',
    created_by: null,
    ...overrides,
  }
}

describe('scheduleStatus', () => {
  it('marks inactive schedules', () => {
    expect(scheduleStatus(schedule({ is_active: false }))).toBe('inactive')
  })

  it('marks upcoming schedules', () => {
    const future = new Date(Date.now() + 86_400_000).toISOString()
    expect(scheduleStatus(schedule({ starts_at: future }))).toBe('upcoming')
  })

  it('marks ended schedules', () => {
    const pastStart = new Date(Date.now() - 172_800_000).toISOString()
    const pastEnd = new Date(Date.now() - 86_400_000).toISOString()
    expect(scheduleStatus(schedule({ starts_at: pastStart, ends_at: pastEnd }))).toBe('ended')
  })

  it('marks active schedules', () => {
    const pastStart = new Date(Date.now() - 86_400_000).toISOString()
    expect(scheduleStatus(schedule({ starts_at: pastStart, ends_at: null }))).toBe('active')
  })
})

describe('statusBadge', () => {
  it('returns class names for each status', () => {
    expect(statusBadge('active')).toContain('green')
    expect(statusBadge('upcoming')).toContain('blue')
    expect(statusBadge('ended')).toContain('gray')
    expect(statusBadge('inactive')).toContain('red')
  })
})

describe('datetime helpers', () => {
  it('formats and parses datetime-local values', () => {
    const local = defaultDatetimeLocal(new Date('2024-06-15T14:30:00'))
    expect(local).toBe('2024-06-15T14:30')
    expect(toDatetimeLocal('2024-06-15T06:30:00.000Z')).toMatch(/2024-06-15T/)
    expect(parseDatetimeLocal('2024-06-15T14:30')).toBeInstanceOf(Date)
    expect(parseDatetimeLocal('')).toBeNull()
    expect(parseDatetimeLocal('bad')).toBeNull()
  })
})
