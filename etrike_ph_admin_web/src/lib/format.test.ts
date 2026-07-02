import { describe, expect, it } from 'vitest'
import {
  driverDisplayName,
  formatDate,
  formatDateTime,
  formatPeso,
  sameDay,
  statusPillClass,
  tripDay,
} from './format'

describe('formatPeso', () => {
  it('formats Philippine peso', () => {
    expect(formatPeso(100)).toContain('₱')
    expect(formatPeso(100)).toContain('100')
  })
})

describe('driverDisplayName', () => {
  it('prefers full name', () => {
    expect(driverDisplayName({ full_name: ' Juan ', email: 'a@b.com' })).toBe('Juan')
  })

  it('falls back to email then Driver', () => {
    expect(driverDisplayName({ email: 'a@b.com' })).toBe('a@b.com')
    expect(driverDisplayName({})).toBe('Driver')
  })
})

describe('formatDate', () => {
  it('returns em dash for empty values', () => {
    expect(formatDate(null)).toBe('—')
  })

  it('formats ISO dates', () => {
    expect(formatDate('2024-06-15T12:00:00Z')).toMatch(/Jun/)
  })
})

describe('formatDateTime', () => {
  it('returns em dash for empty values', () => {
    expect(formatDateTime(undefined)).toBe('—')
  })

  it('formats ISO datetimes', () => {
    expect(formatDateTime('2024-06-15T12:00:00Z')).toMatch(/Jun/)
  })
})

describe('sameDay', () => {
  it('compares calendar days', () => {
    const a = new Date('2024-01-01T08:00:00')
    const b = new Date('2024-01-01T20:00:00')
    const c = new Date('2024-01-02T08:00:00')
    expect(sameDay(a, b)).toBe(true)
    expect(sameDay(a, c)).toBe(false)
  })
})

describe('tripDay', () => {
  it('uses completed_at when available', () => {
    const d = tripDay({ completed_at: '2024-03-01T00:00:00Z', created_at: '2024-02-01T00:00:00Z' })
    expect(d.toISOString()).toContain('2024-03-01')
  })
})

describe('statusPillClass', () => {
  it('returns status-specific classes', () => {
    expect(statusPillClass('approved')).toContain('green')
    expect(statusPillClass('pending')).toContain('amber')
    expect(statusPillClass('rejected')).toContain('red')
    expect(statusPillClass('unknown')).toContain('gray')
  })
})
