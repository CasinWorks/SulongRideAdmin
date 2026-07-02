import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fetchAuditLogs, fetchAuditLogsForDriver, logAudit } from './audit'

const mockFrom = vi.fn()
const mockRpc = vi.fn()
const mockAuthGetUser = vi.fn()

vi.mock('../lib/supabase', () => ({
  supabase: {
    auth: {
      getUser: () => mockAuthGetUser(),
    },
    from: (...args: unknown[]) => mockFrom(...args),
    rpc: (...args: unknown[]) => mockRpc(...args),
  },
}))

function chain(result: unknown) {
  const builder: Record<string, unknown> = {}
  const terminal = Promise.resolve(result)
  for (const method of ['select', 'eq', 'gte', 'lte', 'order', 'limit', 'insert', 'maybeSingle']) {
    builder[method] = vi.fn(() => builder)
  }
  builder.then = terminal.then.bind(terminal)
  builder.catch = terminal.catch.bind(terminal)
  return builder
}

describe('audit service', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('skips logAudit when no user', async () => {
    mockAuthGetUser.mockResolvedValue({ data: { user: null } })
    await logAudit({ action: 'test', summary: 'Test' })
    expect(mockRpc).not.toHaveBeenCalled()
  })

  it('inserts audit log via RPC for signed-in operator', async () => {
    mockAuthGetUser.mockResolvedValue({ data: { user: { id: 'u1', email: 'ops@example.com' } } })
    mockRpc.mockResolvedValue({ data: 'log-id', error: null })

    await logAudit({ action: 'auth.sign_in', summary: 'Signed in' })
    expect(mockRpc).toHaveBeenCalledWith('insert_audit_log', {
      p_action: 'auth.sign_in',
      p_summary: 'Signed in',
      p_entity_type: null,
      p_entity_id: null,
      p_metadata: {},
      p_app_source: 'admin',
    })
  })

  it('fetches audit logs with filters', async () => {
    mockFrom.mockReturnValue(
      chain({
        data: [{ id: '1', summary: 'fare update', action: 'fare.update', created_at: '2024-01-01' }],
        error: null,
      }),
    )

    const rows = await fetchAuditLogs({ search: 'fare', limit: 10 })
    expect(rows).toHaveLength(1)
  })

  it('merges driver audit logs', async () => {
    mockFrom
      .mockReturnValueOnce(
        chain({
          data: [{ id: '1', created_at: '2024-01-02T00:00:00Z' }],
          error: null,
        }),
      )
      .mockReturnValueOnce(
        chain({
          data: [{ id: '2', created_at: '2024-01-03T00:00:00Z' }],
          error: null,
        }),
      )

    const rows = await fetchAuditLogsForDriver('driver-1')
    expect(rows.map((r) => r.id)).toEqual(['2', '1'])
  })
})
