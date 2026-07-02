import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { listDrivers, setDriverApproval } from '../services/admin'
import type { DriverRow } from '../types'
import { driverDisplayName, formatDate } from '../lib/format'
import {
  DividerList,
  ErrorState,
  GhostButton,
  LoadingState,
  PanelCard,
  PrimaryButton,
  ReviewListRow,
} from '../components/ui/adminPageUi'

type Props = {
  status: 'pending' | 'approved' | 'rejected'
  title: string
  subtitle: string
  approveLabel?: string
  rejectLabel?: string
}

export function DriverApprovalPage({
  status,
  title,
  subtitle,
  approveLabel = 'Approve',
  rejectLabel = 'Reject',
}: Props) {
  const [drivers, setDrivers] = useState<DriverRow[]>([])
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)

  const load = useCallback(() => {
    setLoading(true)
    listDrivers(status)
      .then(setDrivers)
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load'))
      .finally(() => setLoading(false))
  }, [status])

  useEffect(() => {
    load()
  }, [load])

  async function handleApproval(driverId: string, next: string) {
    setBusyId(driverId)
    try {
      await setDriverApproval(driverId, next)
      load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Update failed')
    } finally {
      setBusyId(null)
    }
  }

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  return (
    <PanelCard title={title}>
      <p className="mb-4 text-sm text-black/55">{subtitle}</p>
      {drivers.length === 0 ? (
        <p className="py-8 text-center text-black/45">No drivers in this list.</p>
      ) : (
        <DividerList>
          {drivers.map((d) => (
            <ReviewListRow
              key={d.id}
              actions={
                <>
                  {status !== 'approved' ? (
                    <PrimaryButton
                      disabled={busyId === d.id}
                      onClick={() => void handleApproval(d.id, 'approved')}
                    >
                      {approveLabel}
                    </PrimaryButton>
                  ) : null}
                  {status !== 'rejected' ? (
                    <GhostButton
                      disabled={busyId === d.id}
                      onClick={() => void handleApproval(d.id, 'rejected')}
                    >
                      {rejectLabel}
                    </GhostButton>
                  ) : null}
                </>
              }
            >
              <Link to={`/drivers/${d.id}`} className="font-medium text-admin-accent hover:underline">
                {driverDisplayName(d)}
              </Link>
              <p className="text-sm text-black/55">{d.email}</p>
              <p className="text-xs text-black/45">
                {d.trike_plate_number ?? 'No plate'} · {formatDate(d.created_at)}
              </p>
            </ReviewListRow>
          ))}
        </DividerList>
      )}
    </PanelCard>
  )
}
