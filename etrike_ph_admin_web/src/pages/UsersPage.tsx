import { useCallback, useEffect, useState } from 'react'
import { Copy, MailPlus, Pencil } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'
import { operatorDisplayName } from '../lib/displayName'
import {
  listOperators,
  setOperatorApproval,
  setOperatorRole,
  updateOperatorNameByAdmin,
} from '../services/admin'
import {
  createOperatorInvite,
  listOperatorInvites,
  operatorInviteUrl,
  revokeOperatorInvite,
} from '../services/invites'
import type {
  OperatorApprovalStatus,
  OperatorInviteRow,
  OperatorRole,
  OperatorRow,
} from '../types'
import { formatDate } from '../lib/format'
import {
  ErrorState,
  GhostButton,
  LoadingState,
  PanelCard,
  PrimaryButton,
  StatusPill,
} from '../components/ui/adminPageUi'
import { adminInputCls } from '../components/ui/AdminUi'
import { NameFormModal } from '../components/NameFormModal'

const ROLES: OperatorRole[] = ['admin', 'viewer', 'hr', 'dispatcher', 'super_admin']
const INVITE_ROLES: OperatorRole[] = ['viewer', 'hr', 'dispatcher', 'admin', 'super_admin']

function operatorName(op: OperatorRow): string {
  return operatorDisplayName(op)
}

function inviteStatusClass(status: OperatorInviteRow['status']): string {
  if (status === 'pending') return 'bg-amber-50 text-amber-800'
  if (status === 'accepted') return 'bg-emerald-50 text-emerald-800'
  if (status === 'revoked') return 'bg-red-50 text-red-700'
  return 'bg-black/5 text-black/55'
}

export function UsersPage() {
  const { isSuperAdmin, isAdmin } = useAuth()
  const [operators, setOperators] = useState<OperatorRow[]>([])
  const [invites, setInvites] = useState<OperatorInviteRow[]>([])
  const [filter, setFilter] = useState<OperatorApprovalStatus | 'all'>('all')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [inviteEmail, setInviteEmail] = useState('')
  const [inviteRole, setInviteRole] = useState<OperatorRole>('viewer')
  const [inviteBusy, setInviteBusy] = useState(false)
  const [copiedToken, setCopiedToken] = useState<string | null>(null)
  const [editOperator, setEditOperator] = useState<OperatorRow | null>(null)
  const [nameBusy, setNameBusy] = useState(false)

  const load = useCallback(() => {
    setLoading(true)
    const teamPromise = isAdmin
      ? filter === 'all'
        ? listOperators()
        : listOperators(filter)
      : Promise.resolve([] as OperatorRow[])

    Promise.all([teamPromise, listOperatorInvites()])
      .then(([ops, inv]) => {
        setOperators(ops)
        setInvites(inv)
      })
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load team'))
      .finally(() => setLoading(false))
  }, [filter, isAdmin])

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

  async function handleSendInvite(e: React.FormEvent) {
    e.preventDefault()
    setInviteBusy(true)
    setError(null)
    try {
      await createOperatorInvite(inviteEmail, inviteRole)
      setInviteEmail('')
      setInviteRole('viewer')
      load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not send invite')
    } finally {
      setInviteBusy(false)
    }
  }

  async function handleSaveOperatorName(name: string) {
    if (!editOperator) return
    setNameBusy(true)
    try {
      await updateOperatorNameByAdmin(editOperator.id, name)
      setEditOperator(null)
      load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Name update failed')
    } finally {
      setNameBusy(false)
    }
  }

  async function handleRevokeInvite(inviteId: string) {
    setBusyId(inviteId)
    try {
      await revokeOperatorInvite(inviteId)
      load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Revoke failed')
    } finally {
      setBusyId(null)
    }
  }

  async function copyInviteLink(token: string) {
    try {
      await navigator.clipboard.writeText(operatorInviteUrl(token))
      setCopiedToken(token)
      window.setTimeout(() => setCopiedToken(null), 2000)
    } catch {
      setError('Could not copy link')
    }
  }

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  const pendingCount = operators.filter((o) => o.approval_status === 'pending').length
  const inviteRoleOptions = isSuperAdmin
    ? INVITE_ROLES
    : INVITE_ROLES.filter((r) => r !== 'super_admin')

  return (
    <div className="space-y-6">
      <PanelCard title="Send invite">
        <p className="mb-4 text-sm text-black/55">
          Create a unique invite link for a new operator. They sign in through the link; a super
          admin must approve them before dashboard access.
        </p>
        <form
          onSubmit={(e) => void handleSendInvite(e)}
          className="flex flex-wrap items-end gap-3"
        >
          <label className="min-w-[220px] flex-1">
            <span className="mb-1 block text-sm font-medium text-black/70">Email</span>
            <input
              type="email"
              required
              value={inviteEmail}
              onChange={(e) => setInviteEmail(e.target.value)}
              placeholder="operator@company.com"
              className={adminInputCls}
            />
          </label>
          <label>
            <span className="mb-1 block text-sm font-medium text-black/70">Role</span>
            <select
              className="rounded-xl border border-admin-border bg-white px-3 py-2.5 text-sm"
              value={inviteRole}
              onChange={(e) => setInviteRole(e.target.value as OperatorRole)}
            >
              {inviteRoleOptions.map((role) => (
                <option key={role} value={role}>
                  {role.replace('_', ' ')}
                </option>
              ))}
            </select>
          </label>
          <PrimaryButton type="submit" disabled={inviteBusy}>
            <span className="inline-flex items-center gap-2">
              <MailPlus size={16} />
              {inviteBusy ? 'Sending…' : 'Send invite'}
            </span>
          </PrimaryButton>
        </form>
      </PanelCard>

      <PanelCard title="Invite links">
        {invites.length === 0 ? (
          <p className="py-6 text-center text-sm text-black/45">No invites yet.</p>
        ) : (
          <ul className="divide-y divide-admin-border">
            {invites.map((inv) => (
              <li key={inv.id} className="flex flex-wrap items-center justify-between gap-4 py-4">
                <div>
                  <p className="font-medium text-black/87">{inv.email}</p>
                  <p className="text-sm text-black/55">
                    Role: {inv.role.replace('_', ' ')} · Sent {formatDate(inv.created_at)}
                  </p>
                  <p className="text-xs text-black/45">
                    Expires {formatDate(inv.expires_at)}
                    {inv.accepted_at ? ` · Accepted ${formatDate(inv.accepted_at)}` : ''}
                  </p>
                </div>
                <div className="flex flex-wrap items-center gap-2">
                  <span
                    className={`rounded-full px-2.5 py-1 text-xs font-medium capitalize ${inviteStatusClass(inv.status)}`}
                  >
                    {inv.status}
                  </span>
                  {inv.status === 'pending' ? (
                    <>
                      <GhostButton
                        disabled={busyId === inv.id}
                        onClick={() => void copyInviteLink(inv.token)}
                      >
                        <span className="inline-flex items-center gap-1.5">
                          <Copy size={14} />
                          {copiedToken === inv.token ? 'Copied' : 'Copy link'}
                        </span>
                      </GhostButton>
                      <GhostButton
                        disabled={busyId === inv.id}
                        onClick={() => void handleRevokeInvite(inv.id)}
                      >
                        Revoke
                      </GhostButton>
                    </>
                  ) : null}
                </div>
              </li>
            ))}
          </ul>
        )}
      </PanelCard>

      {isAdmin ? (
        <PanelCard
          title="Team members"
          action={
            isSuperAdmin ? (
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
            ) : null
          }
        >
          <p className="mb-4 text-sm text-black/55">
            {isSuperAdmin
              ? 'Approve or revoke operator access, assign roles, and edit display names.'
              : 'Edit operator display names. Approval and roles are managed by super admins.'}
            {isSuperAdmin && pendingCount > 0 ? (
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
                    <GhostButton
                      disabled={busyId === op.id}
                      onClick={() => setEditOperator(op)}
                    >
                      <span className="inline-flex items-center gap-1.5">
                        <Pencil size={14} />
                        Edit name
                      </span>
                    </GhostButton>
                    {isSuperAdmin ? (
                      <>
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
                      </>
                    ) : null}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </PanelCard>
      ) : null}

      <NameFormModal
        key={editOperator?.id ?? 'closed'}
        open={editOperator != null}
        busy={nameBusy}
        title="Edit operator name"
        description={`Update the display name for ${editOperator?.email ?? 'this operator'}.`}
        initialName={editOperator ? operatorName(editOperator) : ''}
        onSave={handleSaveOperatorName}
        onClose={() => setEditOperator(null)}
      />
    </div>
  )
}
