import { describe, expect, it } from 'vitest'
import type { AttendanceRow, DriverRow, LeaveRow } from '../types'
import { buildRosterForDate, dayKey, wasOnShift } from './rosterLogic'

const baseDriver = (overrides: Partial<DriverRow> = {}): DriverRow => ({
  id: 'd1',
  full_name: 'Juan Cruz',
  email: 'juan@test.com',
  phone: '0917',
  trike_plate_number: 'ABC-123',
  trike_model: null,
  approval_status: 'approved',
  created_at: null,
  is_online: false,
  is_available: false,
  employment_type: 'contractual',
  station: 'Carmona Central',
  shift_schedule: 'Mon–Sat · 6:00 AM – 2:00 PM',
  shift_days: [1, 2, 3, 4, 5, 6],
  shift_start: '06:00:00',
  shift_end: '14:00:00',
  emergency_contact: '',
  start_date: null,
  ...overrides,
})

describe('rosterLogic', () => {
  it('marks driver on shift when clocked in', () => {
    const day = new Date(2026, 6, 7)
    const attendance: AttendanceRow[] = [
      {
        id: 'a1',
        driver_id: 'd1',
        clock_in: '2026-07-07T06:00:00Z',
        clock_out: null,
      },
    ]
    const roster = buildRosterForDate(day, [baseDriver()], attendance, [])
    expect(roster.entries[0]?.status).toBe('on_shift')
  })

  it('marks approved leave', () => {
    const day = new Date(2026, 6, 7)
    const leaves: LeaveRow[] = [
      {
        id: 'l1',
        driver_id: 'd1',
        leave_type: 'VL',
        start_date: '2026-07-01',
        end_date: '2026-07-31',
        status: 'approved',
        reason: null,
        created_at: '2026-07-01',
      },
    ]
    const roster = buildRosterForDate(day, [baseDriver()], [], leaves)
    expect(roster.entries[0]?.status).toBe('on_leave_vl')
  })

  it('wasOnShift spans overnight into next calendar day', () => {
    const day = new Date(2026, 6, 7)
    const row: AttendanceRow = {
      id: 'a1',
      driver_id: 'd1',
      clock_in: '2026-07-06T22:00:00Z',
      clock_out: '2026-07-07T06:00:00Z',
    }
    expect(wasOnShift(row, day)).toBe(true)
    expect(dayKey(day)).toBe('2026-07-07')
  })
})
