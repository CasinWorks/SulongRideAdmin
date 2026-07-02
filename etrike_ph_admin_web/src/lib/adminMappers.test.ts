import { describe, expect, it } from 'vitest'
import {
  DEFAULT_FARE,
  mapDriver,
  mapFareConfig,
  mapFareSchedule,
  mapOperator,
  mapTrip,
} from './adminMappers'

describe('adminMappers', () => {
  it('maps driver rows with defaults', () => {
    const driver = mapDriver({ id: 'd1', email: 'a@b.com' })
    expect(driver.id).toBe('d1')
    expect(driver.approval_status).toBe('pending')
    expect(driver.station).toBe('Carmona Central')
  })

  it('maps trip rows and complaint tags', () => {
    const trip = mapTrip({
      id: 't1',
      created_at: '2024-01-01T00:00:00Z',
      fare: '50',
      complaint_tags: ['late'],
    })
    expect(trip.fare).toBe(50)
    expect(trip.complaint_tags).toEqual(['late'])
  })

  it('maps operator rows', () => {
    const op = mapOperator({ id: 'o1', role: 'super_admin' })
    expect(op.role).toBe('super_admin')
  })

  it('maps fare config and schedules', () => {
    const config = mapFareConfig({ id: 'f1', base_fare: 45 })
    expect(config.base_fare).toBe(45)
    expect(config.currency).toBe(DEFAULT_FARE.currency)

    const schedule = mapFareSchedule({
      id: 's1',
      label: 'Peak',
      starts_at: '2024-01-01T00:00:00Z',
    })
    expect(schedule.label).toBe('Peak')
    expect(schedule.schedule_type).toBe('discount')
  })
})
