import { useCallback, useEffect, useState } from 'react'
import { listOperators, setOperatorApproval, setOperatorRole } from '../services/admin'
import type { OperatorApprovalStatus, OperatorRole, OperatorRow } from '../types'
import { formatDate } from '../lib/format'
import {
  ErrorState,
  GhostButton,
  LoadingState,
  PanelCard,
  PrimaryButton,
  StatusPill,
} from '../components/ui/adminPageUi'

const ROLES: OperatorRole[] = ['admin', 'viewer', 'super_admin']

function operatorName(op: OperatorRow): string {
  const name = op.full_name?.trim()
  if (name) return name
  return op.email.split('@')[0] || 'Operator'
}

export function UsersPage() {
  const [operators, setOperators] = useState<OperatorRow[]>([])
  const [filter, setFilter] = useState<OperatorApprovalStatus | 'all'>('all')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)

  const load = useCallback(() => {
    setLoading(true)
    const promise =
      filter === 'all' ? listOperators() : listOperators(filter)
    promise
      .then(setOperators)
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load team'))
      .finally(() => setLoading(false))
  }, [filter])

  useEffect(() => {
    load()
  }, [load])

  async function handleApproval(operatorId: string, status: OperatorApprovalStatus) {
    setBusyId(operatorId)
    try {
      await setOperatorApproval(operatorId, status)
      load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Update failed')
    } finally {
      setBusyId(null)
    }
  }

  async function handleRoleChange(operatorId: string, role: OperatorRole) {
    setBusyId(operatorId)
    try {
      await setOperatorRole(operatorId, role)
      load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Role update failed')
    } finally {
      setBusyId(null)
    }
  }

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  const pendingCount = operators.filter((o) => o.approval_status === 'pending').length

  return (
    <div className="space-y-6">
      <PanelCard
        title="Team access"
        action={
          <div className="flex flex-wrap gap-2">
            {(['all', 'pending', 'approved', 'revoked'] as const).map((value) => (
              <GhostButton
                key={value}
                onClick={() => setFilter(value)}
                disabled={filter === value}
              >
                {value === 'all' ? 'All' : value}
              </GhostButton>
            ))}
          </div>
        }
      >
        <p className="mb-4 text-sm text-black/55">
          Approve or revoke operator access and assign roles. Only super admins can manage team
          members.
          {pendingCount > 0 ? (
            <span className="mt-1 block font-medium text-amber-700">
              {pendingCount} user{pendingCount === 1 ? '' : 's'} waiting for approval.
            </span>
          ) : null}
        </p>

        {operators.length === 0 ? (
          <p className="py-8 text-center text-black/45">No team members in this list.</p>
        ) : (
          <ul className="divide-y divide-admin-border">
            {operators.map((op) => (
              <li key={op.id} className="flex flex-wrap items-center justify-between gap-4 py-4">
                <div>
                  <p className="font-medium text-black/87">{operatorName(op)}</p>
                  <p className="text-sm text-black/55">{op.email}</p>
                  <p className="text-xs text-black/45">
                    Joined {formatDate(op.created_at)} · Role: {op.role.replace('_', ' ')}
                  </p>
                </div>
                <div className="flex flex-wrap items-center gap-2">
                  <StatusPill status={op.approval_status} />
                  <select
                    className="rounded-xl border border-admin-border bg-white px-3 py-2 text-sm"
                    value={op.role}
                    disabled={busyId === op.id}
                    onChange={(e) =>
                      void handleRoleChange(op.id, e.target.value as OperatorRole)
                    }
                  >
                    {ROLES.map((role) => (
                      <option key={role} value={role}>
                        {role.replace('_', ' ')}
                      </option>
                    ))}
                  </select>
                  {op.approval_status !== 'approved' ? (
                    <PrimaryButton
                      disabled={busyId === op.id}
                      onClick={() => void handleApproval(op.id, 'approved')}
                    >
                      Approve
                    </PrimaryButton>
                  ) : (
                    <GhostButton
                      disabled={busyId === op.id}
                      onClick={() => void handleApproval(op.id, 'revoked')}
                    >
                      Revoke
                    </GhostButton>
                  )}
                  {op.approval_status === 'revoked' ? (
                    <GhostButton
                      disabled={busyId === op.id}
                      onClick={() => void handleApproval(op.id, 'pending')}
                    >
                      Mark pending
                    </GhostButton>
                  ) : null}
                </div>
              </li>
            ))}
          </ul>
        )}
      </PanelCard>
    </div>
  )
}
