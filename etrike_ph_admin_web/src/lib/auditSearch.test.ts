import { describe, expect, it } from 'vitest'
import { endOfDayIso, matchesAuditSearch } from './auditSearch'
import type { AuditLogRow } from '../types'

const row: AuditLogRow = {
  id: '1',
  actor_id: 'a1',
  actor_role: 'operator',
  actor_email: 'ops@example.com',
  action: 'fare.update',
  entity_type: 'fare_config',
  entity_id: 'f1',
  summary: 'Default fare updated',
  metadata: {},
  app_source: 'admin',
  created_at: '2024-01-01T00:00:00Z',
}

describe('auditSearch', () => {
  it('builds end-of-day ISO timestamps', () => {
    expect(endOfDayIso('2024-06-15')).toContain('2024-06-15')
  })

  it('matches audit rows by search text', () => {
    expect(matchesAuditSearch(row, '')).toBe(true)
    expect(matchesAuditSearch(row, 'fare')).toBe(true)
    expect(matchesAuditSearch(row, 'missing')).toBe(false)
  })
})
