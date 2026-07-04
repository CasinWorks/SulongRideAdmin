import { describe, expect, it } from 'vitest'
import { shiftDisplayString, shiftWorksOn, parseShiftDays, timeToPg } from './shiftConfig'

describe('shiftConfig', () => {
  it('formats Mon–Sat morning shift', () => {
    const text = shiftDisplayString({
      days: parseShiftDays([1, 2, 3, 4, 5, 6]),
      startHour: 6,
      startMinute: 0,
      endHour: 14,
      endMinute: 0,
      station: 'Carmona Central',
      employmentType: 'contractual',
    })
    expect(text).toBe('Mon–Sat · 6:00 AM – 2:00 PM')
  })

  it('detects work days (ISO Mon=1)', () => {
    const config = {
      days: parseShiftDays([1, 2, 3, 4, 5, 6]),
      startHour: 6,
      startMinute: 0,
      endHour: 14,
      endMinute: 0,
      station: 'Carmona Central',
      employmentType: 'contractual',
    }
    // Monday 2026-07-06
    expect(shiftWorksOn(config, new Date(2026, 6, 6))).toBe(true)
    // Sunday 2026-07-05
    expect(shiftWorksOn(config, new Date(2026, 6, 5))).toBe(false)
  })

  it('serializes postgres time', () => {
    expect(timeToPg(14, 30)).toBe('14:30:00')
  })
})
