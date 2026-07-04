import { describe, expect, it } from 'vitest'
import { auditActorRole } from './auditActorRole'

describe('auditActorRole', () => {
  it('maps known operator roles', () => {
    expect(auditActorRole('super_admin')).toBe('super_admin')
    expect(auditActorRole('admin')).toBe('admin')
    expect(auditActorRole('viewer')).toBe('viewer')
    expect(auditActorRole('hr')).toBe('hr')
    expect(auditActorRole('dispatcher')).toBe('dispatcher')
  })

  it('maps mobile roles', () => {
    expect(auditActorRole('driver')).toBe('driver')
    expect(auditActorRole('rider')).toBe('rider')
  })

  it('defaults to operator', () => {
    expect(auditActorRole(null)).toBe('operator')
    expect(auditActorRole('unknown')).toBe('operator')
  })
})
