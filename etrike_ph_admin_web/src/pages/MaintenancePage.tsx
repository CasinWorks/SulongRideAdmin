import { useEffect, useMemo, useState } from 'react'
import {
  cancelMaintenance,
  confirmOperatorPassword,
  endMaintenanceNow,
  extendMaintenance,
  fetchAppMaintenanceStatus,
  fetchOpenMaintenanceWindow,
  listMaintenanceWindows,
  scheduleMaintenance,
} from '../services/maintenance'
import type { AppMaintenanceRow, AppMaintenanceStatus } from '../types/maintenance'
import { formatDateTime } from '../lib/format'
import {
  ErrorState,
  GhostButton,
  LoadingState,
  PanelCard,
  PrimaryButton,
} from '../components/ui/adminPageUi'
import { adminInputCls } from '../components/ui/AdminUi'
import { PasswordConfirmModal } from '../components/ui/PasswordConfirmModal'

type PendingAction =
  | { type: 'schedule'; payload: null }
  | { type: 'extend'; payload: { id: string; newEndsAt: string } }
  | { type: 'end'; payload: { id: string } }
  | { type: 'cancel'; payload: { id: string } }

function defaultScheduleRange() {
  const start = new Date()
  start.setMinutes(start.getMinutes() + 30)
  const end = new Date(start)
  end.setHours(end.getHours() + 2)
  const toLocal = (d: Date) => {
    const pad = (n: number) => String(n).padStart(2, '0')
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
  }
  return { start: toLocal(start), end: toLocal(end) }
}

function phaseLabel(phase: AppMaintenanceStatus['phase']): string {
  switch (phase) {
    case 'active':
      return 'Active now'
    case 'scheduled':
      return 'Upcoming'
    default:
      return 'None'
  }
}

export function MaintenancePage() {
  const defaults = useMemo(() => defaultScheduleRange(), [])
  const [liveStatus, setLiveStatus] = useState<AppMaintenanceStatus | null>(null)
  const [openWindow, setOpenWindow] = useState<AppMaintenanceRow | null>(null)
  const [history, setHistory] = useState<AppMaintenanceRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  const [title, setTitle] = useState('Scheduled maintenance')
  const [message, setMessage] = useState(
    'Sulong Ride is temporarily unavailable while we perform maintenance. Please check back soon.',
  )
  const [startsAt, setStartsAt] = useState(defaults.start)
  const [endsAt, setEndsAt] = useState(defaults.end)
  const [blockApps, setBlockApps] = useState(true)
  const [notifyUsers, setNotifyUsers] = useState(true)
  const [extendEndsAt, setExtendEndsAt] = useState(defaults.end)

  const [passwordOpen, setPasswordOpen] = useState(false)
  const [password, setPassword] = useState('')
  const [passwordError, setPasswordError] = useState<string | null>(null)
  const [pendingAction, setPendingAction] = useState<PendingAction | null>(null)

  function load() {
    setLoading(true)
    setError(null)
    Promise.all([
      fetchAppMaintenanceStatus(),
      fetchOpenMaintenanceWindow(),
      listMaintenanceWindows(),
    ])
      .then(([status, open, rows]) => {
        setLiveStatus(status)
        setOpenWindow(open)
        setHistory(rows)
        if (open) {
          setExtendEndsAt(open.ends_at.slice(0, 16))
        }
      })
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load'))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    load()
    const timer = window.setInterval(() => {
      fetchAppMaintenanceStatus()
        .then(setLiveStatus)
        .catch(() => {})
      fetchOpenMaintenanceWindow()
        .then(setOpenWindow)
        .catch(() => {})
    }, 15000)
    return () => window.clearInterval(timer)
  }, [])

  function requestPassword(action: PendingAction) {
    setPendingAction(action)
    setPassword('')
    setPasswordError(null)
    setPasswordOpen(true)
  }

  async function executePendingAction() {
    if (!pendingAction) return
    setBusy(true)
    setPasswordError(null)
    try {
      await confirmOperatorPassword(password)
      if (pendingAction.type === 'schedule') {
        await scheduleMaintenance({
          title,
          message,
          starts_at: new Date(startsAt).toISOString(),
          ends_at: new Date(endsAt).toISOString(),
          block_apps: blockApps,
          notify_users: notifyUsers,
        })
      } else if (pendingAction.type === 'extend') {
        await extendMaintenance(
          pendingAction.payload.id,
          new Date(pendingAction.payload.newEndsAt).toISOString(),
        )
      } else if (pendingAction.type === 'end') {
        await endMaintenanceNow(pendingAction.payload.id)
      } else if (pendingAction.type === 'cancel') {
        await cancelMaintenance(pendingAction.payload.id)
      }
      setPasswordOpen(false)
      setPendingAction(null)
      setPassword('')
      load()
    } catch (e) {
      setPasswordError(e instanceof Error ? e.message : 'Action failed')
    } finally {
      setBusy(false)
    }
  }

  if (loading) return <LoadingState />
  if (error && !liveStatus) return <ErrorState message={error} />

  const mobilePhase = liveStatus?.phase ?? 'inactive'

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold">App maintenance</h2>
        <p className="mt-1 text-sm text-black/55">
          Schedule downtime for the driver and rider apps. Users see notifications when enabled;
          when active and &quot;Block apps&quot; is on, both mobile apps halt until the window
          ends or you close it early. Password confirmation is required for every change.
        </p>
      </div>

      {error ? <p className="text-sm text-red-700">{error}</p> : null}

      <PanelCard title="Live status (mobile apps)">
        <div className="flex flex-wrap items-center gap-3">
          <span
            className={`rounded-full px-3 py-1 text-sm font-medium ${
              mobilePhase === 'active'
                ? 'bg-red-100 text-red-800'
                : mobilePhase === 'scheduled'
                  ? 'bg-amber-100 text-amber-900'
                  : 'bg-green-100 text-green-800'
            }`}
          >
            {phaseLabel(mobilePhase)}
          </span>
          {liveStatus?.title && mobilePhase !== 'inactive' ? (
            <span className="text-sm text-black/70">{liveStatus.title}</span>
          ) : null}
        </div>
        {liveStatus && mobilePhase !== 'inactive' ? (
          <dl className="mt-4 grid gap-2 text-sm sm:grid-cols-2">
            <div>
              <dt className="text-black/45">Message</dt>
              <dd>{liveStatus.message}</dd>
            </div>
            <div>
              <dt className="text-black/45">Window</dt>
              <dd>
                {liveStatus.starts_at ? formatDateTime(liveStatus.starts_at) : '—'} →{' '}
                {liveStatus.ends_at ? formatDateTime(liveStatus.ends_at) : '—'}
              </dd>
            </div>
            <div>
              <dt className="text-black/45">Block apps</dt>
              <dd>{liveStatus.block_apps ? 'Yes' : 'No'}</dd>
            </div>
            <div>
              <dt className="text-black/45">Notify users</dt>
              <dd>{liveStatus.notify_users ? 'Yes' : 'No'}</dd>
            </div>
          </dl>
        ) : (
          <p className="mt-3 text-sm text-black/50">No maintenance affecting apps right now.</p>
        )}
      </PanelCard>

      {openWindow ? (
        <PanelCard title="Current open window">
          <dl className="grid gap-2 text-sm sm:grid-cols-2">
            <div>
              <dt className="text-black/45">Title</dt>
              <dd className="font-medium">{openWindow.title}</dd>
            </div>
            <div>
              <dt className="text-black/45">Status</dt>
              <dd className="capitalize">{openWindow.status}</dd>
            </div>
            <div className="sm:col-span-2">
              <dt className="text-black/45">Message</dt>
              <dd>{openWindow.message}</dd>
            </div>
            <div>
              <dt className="text-black/45">Starts</dt>
              <dd>{formatDateTime(openWindow.starts_at)}</dd>
            </div>
            <div>
              <dt className="text-black/45">Ends</dt>
              <dd>{formatDateTime(openWindow.ends_at)}</dd>
            </div>
          </dl>

          <div className="mt-4 grid gap-4 lg:grid-cols-2">
            <label className="block text-sm">
              <span className="font-medium text-black/70">Extend until</span>
              <input
                type="datetime-local"
                className={adminInputCls}
                value={extendEndsAt}
                onChange={(e) => setExtendEndsAt(e.target.value)}
              />
            </label>
            <div className="flex flex-wrap items-end gap-2">
              <PrimaryButton
                disabled={busy}
                onClick={() =>
                  requestPassword({
                    type: 'extend',
                    payload: { id: openWindow.id, newEndsAt: extendEndsAt },
                  })
                }
              >
                Extend window
              </PrimaryButton>
              <GhostButton
                disabled={busy}
                onClick={() => requestPassword({ type: 'end', payload: { id: openWindow.id } })}
              >
                End now
              </GhostButton>
              <GhostButton
                disabled={busy}
                onClick={() =>
                  requestPassword({ type: 'cancel', payload: { id: openWindow.id } })
                }
              >
                Cancel schedule
              </GhostButton>
            </div>
          </div>
        </PanelCard>
      ) : null}

      <PanelCard title="Schedule maintenance">
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="block text-sm sm:col-span-2">
            <span className="font-medium text-black/70">Title</span>
            <input className={adminInputCls} value={title} onChange={(e) => setTitle(e.target.value)} />
          </label>
          <label className="block text-sm sm:col-span-2">
            <span className="font-medium text-black/70">User-facing message</span>
            <textarea
              className={`${adminInputCls} min-h-[88px]`}
              value={message}
              onChange={(e) => setMessage(e.target.value)}
            />
          </label>
          <label className="block text-sm">
            <span className="font-medium text-black/70">Starts</span>
            <input
              type="datetime-local"
              className={adminInputCls}
              value={startsAt}
              onChange={(e) => setStartsAt(e.target.value)}
            />
          </label>
          <label className="block text-sm">
            <span className="font-medium text-black/70">Ends</span>
            <input
              type="datetime-local"
              className={adminInputCls}
              value={endsAt}
              onChange={(e) => setEndsAt(e.target.value)}
            />
          </label>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={notifyUsers}
              onChange={(e) => setNotifyUsers(e.target.checked)}
            />
            Show maintenance notification before start
          </label>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={blockApps}
              onChange={(e) => setBlockApps(e.target.checked)}
            />
            Block driver &amp; rider apps during window
          </label>
        </div>
        <PrimaryButton
          disabled={busy || Boolean(openWindow)}
          onClick={() => requestPassword({ type: 'schedule', payload: null })}
        >
          Schedule maintenance
        </PrimaryButton>
        {openWindow ? (
          <p className="mt-2 text-xs text-black/45">
            End or cancel the current window before scheduling another.
          </p>
        ) : null}
      </PanelCard>

      <PanelCard title="History">
        {history.length === 0 ? (
          <p className="text-sm text-black/45">No maintenance windows recorded yet.</p>
        ) : (
          <ul className="divide-y divide-admin-border text-sm">
            {history.map((row) => (
              <li key={row.id} className="flex flex-wrap justify-between gap-3 py-3">
                <div>
                  <p className="font-medium">{row.title}</p>
                  <p className="text-black/55">{row.message}</p>
                  <p className="mt-1 text-xs text-black/45">
                    {formatDateTime(row.starts_at)} → {formatDateTime(row.ends_at)}
                    {row.ended_early_at ? ` · ended early ${formatDateTime(row.ended_early_at)}` : ''}
                  </p>
                </div>
                <span className="rounded-full bg-admin-bg px-2.5 py-0.5 text-xs font-medium capitalize">
                  {row.status}
                </span>
              </li>
            ))}
          </ul>
        )}
      </PanelCard>

      <PasswordConfirmModal
        open={passwordOpen}
        title="Confirm with your password"
        description="Enter your operator account password to apply this maintenance change."
        confirmLabel={
          pendingAction?.type === 'schedule'
            ? 'Schedule maintenance'
            : pendingAction?.type === 'extend'
              ? 'Extend window'
              : pendingAction?.type === 'end'
                ? 'End maintenance now'
                : 'Cancel maintenance'
        }
        password={password}
        busy={busy}
        error={passwordError}
        onPasswordChange={setPassword}
        onConfirm={() => void executePendingAction()}
        onClose={() => {
          if (busy) return
          setPasswordOpen(false)
          setPendingAction(null)
          setPasswordError(null)
        }}
      />
    </div>
  )
}
