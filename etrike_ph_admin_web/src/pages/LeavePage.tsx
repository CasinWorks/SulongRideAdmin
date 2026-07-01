import { useCallback, useEffect, useState } from 'react'
import { listLeaveRequests, reviewLeaveRequest } from '../services/admin'
import type { LeaveRow } from '../types'
import { formatDate, driverDisplayName } from '../lib/format'
import {
  ErrorState,
  GhostButton,
  LoadingState,
  PanelCard,
  PrimaryButton,
  StatusPill,
} from '../components/ui/AdminUi'

export function LeavePage() {
  const [rows, setRows] = useState<LeaveRow[]>([])
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)

  const load = useCallback(() => {
    setLoading(true)
    listLeaveRequests('pending')
      .then(setRows)
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load leave'))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => {
    load()
  }, [load])

  async function review(id: string, status: 'approved' | 'rejected') {
    setBusyId(id)
    try {
      await reviewLeaveRequest(id, status)
      load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Review failed')
    } finally {
      setBusyId(null)
    }
  }

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  return (
    <PanelCard title="Pending leave requests">
      {rows.length === 0 ? (
        <p className="py-8 text-center text-black/45">No pending leave requests.</p>
      ) : (
        <ul className="divide-y divide-admin-border">
          {rows.map((r) => (
            <li key={r.id} className="flex flex-wrap items-center justify-between gap-4 py-4">
              <div>
                <p className="font-medium">
                  {r.drivers ? driverDisplayName(r.drivers) : r.driver_id}
                </p>
                <p className="text-sm text-black/55">
                  {r.leave_type} · {formatDate(r.start_date)} – {formatDate(r.end_date)}
                </p>
                {r.reason ? <p className="text-xs text-black/45">{r.reason}</p> : null}
                <StatusPill status={r.status} />
              </div>
              <div className="flex gap-2">
                <PrimaryButton
                  disabled={busyId === r.id}
                  onClick={() => void review(r.id, 'approved')}
                >
                  Approve
                </PrimaryButton>
                <GhostButton
                  disabled={busyId === r.id}
                  onClick={() => void review(r.id, 'rejected')}
                >
                  Reject
                </GhostButton>
              </div>
            </li>
          ))}
        </ul>
      )}
    </PanelCard>
  )
}
