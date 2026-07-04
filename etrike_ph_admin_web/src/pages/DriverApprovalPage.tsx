import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { listDrivers, setDriverApproval } from '../services/admin'
import { setDriverPendingRequirements } from '../services/onboarding'
import { RequireDocumentsModal } from '../components/onboarding/RequireDocumentsModal'
import type { DocumentTypeId } from '../lib/onboardingConstants'
import { driverDisplayName, formatDate } from '../lib/format'
import type { DriverRow } from '../types'
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
  const { canWriteDrivers } = useAuth()
  const [drivers, setDrivers] = useState<DriverRow[]>([])
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [requireDocsDriver, setRequireDocsDriver] = useState<DriverRow | null>(null)
  const [requireDocsBusy, setRequireDocsBusy] = useState(false)
  const [requireDocsError, setRequireDocsError] = useState<string | null>(null)

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

  async function handleRequireDocuments(reason: string, requiredDocTypes: DocumentTypeId[]) {
    if (!requireDocsDriver) return
    setRequireDocsBusy(true)
    setRequireDocsError(null)
    try {
      await setDriverPendingRequirements(requireDocsDriver.id, {
        reason,
        requiredDocTypes,
        driverName: driverDisplayName(requireDocsDriver),
      })
      setRequireDocsDriver(null)
      load()
    } catch (e) {
      setRequireDocsError(e instanceof Error ? e.message : 'Update failed')
    } finally {
      setRequireDocsBusy(false)
    }
  }

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  return (
    <>
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
                    {status === 'pending' ? (
                      <Link to={`/drivers/onboarding/${d.id}`}>
                        <GhostButton>Onboard</GhostButton>
                      </Link>
                    ) : null}
                    {canWriteDrivers && status === 'approved' ? (
                      <GhostButton
                        disabled={busyId === d.id || requireDocsBusy}
                        onClick={() => {
                          setRequireDocsError(null)
                          setRequireDocsDriver(d)
                        }}
                      >
                        Require docs
                      </GhostButton>
                    ) : null}
                    {canWriteDrivers && status !== 'approved' ? (
                      <PrimaryButton
                        disabled={busyId === d.id}
                        onClick={() => void handleApproval(d.id, 'approved')}
                      >
                        {approveLabel}
                      </PrimaryButton>
                    ) : null}
                    {canWriteDrivers && status !== 'rejected' ? (
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

      <RequireDocumentsModal
        open={requireDocsDriver != null}
        driverName={requireDocsDriver ? driverDisplayName(requireDocsDriver) : ''}
        busy={requireDocsBusy}
        error={requireDocsError}
        onConfirm={(reason, docTypes) => void handleRequireDocuments(reason, docTypes)}
        onClose={() => setRequireDocsDriver(null)}
      />
    </>
  )
}
