import { useCallback, useEffect, useState } from 'react'
import { useAuth } from '../hooks/useAuth'
import { listLeaveRequests, reviewLeaveRequest } from '../services/admin'
import type { LeaveRow } from '../types'
import { formatDate, driverDisplayName } from '../lib/format'
import {
  DividerList,
  ErrorState,
  GhostButton,
  LoadingState,
  PanelCard,
  PrimaryButton,
  ReviewListRow,
  StatusPill,
} from '../components/ui/adminPageUi'

export function LeavePage() {
  const { canWriteHr } = useAuth()
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
        <DividerList>
          {rows.map((r) => (
            <ReviewListRow
              key={r.id}
              actions={
                canWriteHr ? (
                  <>
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
                  </>
                ) : null
              }
            >
              <p className="font-medium">
                {r.drivers ? driverDisplayName(r.drivers) : r.driver_id}
              </p>
              <p className="text-sm text-black/55">
                {r.leave_type} · {formatDate(r.start_date)} – {formatDate(r.end_date)}
              </p>
              {r.reason ? <p className="text-xs text-black/45">{r.reason}</p> : null}
              <StatusPill status={r.status} />
            </ReviewListRow>
          ))}
        </DividerList>
      )}
    </PanelCard>
  )
}
