import { useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Pencil } from 'lucide-react'
import {
  acknowledgeTripReview,
  deleteDriverCompletely,
  fetchDriverProfile,
  setDriverApproval,
  updateDriverName,
} from '../services/admin'
import { fetchOnboardingBundle, setDriverPendingRequirements } from '../services/onboarding'
import { DriverTrainingPanel } from '../components/training/DriverTrainingPanel'
import { DriverVehicleAssignPanel } from '../components/fleet/DriverVehicleAssignPanel'
import { DriverDocumentsPanel } from '../components/onboarding/DriverDocumentsPanel'
import { RequireDocumentsModal } from '../components/onboarding/RequireDocumentsModal'
import { ConfirmPermanentDeleteModal } from '../components/ui/ConfirmPermanentDeleteModal'
import { useAuth } from '../hooks/useAuth'
import type { DriverDocumentRow } from '../types/onboarding'
import type { DocumentTypeId } from '../lib/onboardingConstants'
import { formatDateTime, formatPeso } from '../lib/format'
import { NameFormModal } from '../components/NameFormModal'
import {
  ErrorState,
  GhostButton,
  LoadingState,
  PanelCard,
  PrimaryButton,
  StatCard,
  StatusPill,
} from '../components/ui/adminPageUi'
import type { DriverProfile } from '../types'

export function DriverDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { isAdmin, canWriteDrivers } = useAuth()
  const [profile, setProfile] = useState<DriverProfile | null>(null)
  const [documents, setDocuments] = useState<DriverDocumentRow[]>([])
  const [checklistPercent, setChecklistPercent] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [editNameOpen, setEditNameOpen] = useState(false)
  const [nameBusy, setNameBusy] = useState(false)
  const [deleteOpen, setDeleteOpen] = useState(false)
  const [deleteToken, setDeleteToken] = useState('')
  const [deleteBusy, setDeleteBusy] = useState(false)
  const [requireDocsOpen, setRequireDocsOpen] = useState(false)
  const [requireDocsBusy, setRequireDocsBusy] = useState(false)
  const [requireDocsError, setRequireDocsError] = useState<string | null>(null)

  function load() {
    if (!id) return
    setLoading(true)
    Promise.all([fetchDriverProfile(id), fetchOnboardingBundle(id)])
      .then(([driverProfile, bundle]) => {
        setProfile(driverProfile)
        setDocuments(bundle.documents)
        setChecklistPercent(bundle.checklist_percent)
      })
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load driver'))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id])

  async function handleApproval(status: string) {
    if (!id) return
    setBusy(true)
    try {
      await setDriverApproval(id, status)
      load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Update failed')
    } finally {
      setBusy(false)
    }
  }

  async function acknowledge(tripId: string) {
    setBusy(true)
    try {
      await acknowledgeTripReview(tripId)
      load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Acknowledge failed')
    } finally {
      setBusy(false)
    }
  }

  async function handleSaveDriverName(name: string) {
    if (!id) return
    setNameBusy(true)
    try {
      await updateDriverName(id, name)
      setEditNameOpen(false)
      load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Name update failed')
    } finally {
      setNameBusy(false)
    }
  }

  async function handleDeleteDriver() {
    if (!id || !profile) return
    setDeleteBusy(true)
    setError(null)
    try {
      await deleteDriverCompletely(id)
      navigate('/drivers')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Delete failed')
    } finally {
      setDeleteBusy(false)
    }
  }

  async function handleRequireDocuments(reason: string, requiredDocTypes: DocumentTypeId[]) {
    if (!id || !profile) return
    setRequireDocsBusy(true)
    setRequireDocsError(null)
    try {
      await setDriverPendingRequirements(id, {
        reason,
        requiredDocTypes,
        driverName: profile.fullName,
      })
      setRequireDocsOpen(false)
      load()
    } catch (e) {
      setRequireDocsError(e instanceof Error ? e.message : 'Update failed')
    } finally {
      setRequireDocsBusy(false)
    }
  }

  if (!id) return <ErrorState message="Missing driver id" />
  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />
  if (!profile) return null

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <Link to="/drivers" className="text-sm text-admin-accent hover:underline">
            ← Back to drivers
          </Link>
          <h2 className="mt-2 text-2xl font-semibold">{profile.fullName}</h2>
          <p className="text-sm text-black/55">{profile.email}</p>
          <div className="mt-2 flex flex-wrap gap-2">
            <StatusPill status={profile.approvalStatus} />
            <span className="rounded-full bg-admin-bg px-2.5 py-0.5 text-xs text-black/55">
              {profile.statusLabel}
            </span>
          </div>
          <div className="mt-2 flex flex-wrap items-center gap-2">
            {canWriteDrivers ? (
              <GhostButton disabled={busy} onClick={() => setEditNameOpen(true)}>
                <span className="inline-flex items-center gap-1.5">
                  <Pencil size={14} />
                  Edit name
                </span>
              </GhostButton>
            ) : null}
            {profile.approvalStatus === 'pending' ? (
              <Link
                to={`/drivers/onboarding/${id}`}
                className="inline-flex items-center rounded-xl border border-admin-border bg-admin-bg px-3 py-2 text-sm font-medium text-black/70 hover:bg-white"
              >
                Open onboarding wizard
              </Link>
            ) : null}
          </div>
        </div>
        {canWriteDrivers ? (
          <div className="flex flex-wrap gap-2">
            {profile.approvalStatus !== 'approved' ? (
              <PrimaryButton disabled={busy} onClick={() => void handleApproval('approved')}>
                Approve
              </PrimaryButton>
            ) : null}
            {profile.approvalStatus === 'approved' ? (
              <GhostButton
                disabled={busy}
                onClick={() => {
                  setRequireDocsError(null)
                  setRequireDocsOpen(true)
                }}
              >
                Require documents
              </GhostButton>
            ) : null}
            {profile.approvalStatus !== 'rejected' ? (
              <GhostButton disabled={busy} onClick={() => void handleApproval('rejected')}>
                Revoke
              </GhostButton>
            ) : null}
          </div>
        ) : null}
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard label="Overall rating" value={`${profile.overallRating.toFixed(1)}★`} />
        <StatCard label="Total trips" value={String(profile.totalTrips)} />
        <StatCard label="Trips this month" value={String(profile.tripsThisMonth)} />
        <StatCard label="Total earnings" value={formatPeso(profile.totalEarnings)} />
      </div>

      <DriverDocumentsPanel
        driverId={id!}
        documents={documents}
        checklistPercent={checklistPercent}
        title="Compliance documents"
        readOnly={!canWriteDrivers}
        driverName={profile.fullName}
        onChanged={load}
      />

      <DriverTrainingPanel driverId={id} driverName={profile.fullName} readOnly={!canWriteDrivers} />

      <DriverVehicleAssignPanel
        driverId={id}
        driverName={profile.fullName}
        onChanged={load}
        readOnly={!canWriteDrivers}
      />

      <div className="grid gap-6 lg:grid-cols-2">
        <PanelCard title="Profile">
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between gap-4">
              <dt className="text-black/45">Phone</dt>
              <dd>{profile.phone}</dd>
            </div>
            <div className="flex justify-between gap-4">
              <dt className="text-black/45">Plate</dt>
              <dd>{profile.plate}</dd>
            </div>
          </dl>
        </PanelCard>

        <PanelCard title="Low ratings & reviews">
          {profile.lowRatingReviews.length === 0 ? (
            <p className="text-sm text-black/45">No low ratings on record.</p>
          ) : (
            <ul className="space-y-3">
              {profile.lowRatingReviews.map((t) => (
                <li key={t.id} className="rounded-xl bg-admin-bg p-3 text-sm">
                  <p className="font-medium">{t.rating}★ — {formatPeso(t.fare)}</p>
                  <p className="text-black/55">{t.review_text ?? 'No comment'}</p>
                  {!t.review_acknowledged_at && canWriteDrivers ? (
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => void acknowledge(t.id)}
                      className="mt-2 text-xs font-medium text-admin-accent"
                    >
                      Acknowledge review
                    </button>
                  ) : !t.review_acknowledged_at ? null : (
                    <p className="mt-1 text-xs text-green-700">Acknowledged</p>
                  )}
                </li>
              ))}
            </ul>
          )}
        </PanelCard>
      </div>

      <PanelCard title="Recent trips">
        {profile.recentTrips.length === 0 ? (
          <p className="text-sm text-black/45">No completed trips yet.</p>
        ) : (
          <ul className="divide-y divide-admin-border text-sm">
            {profile.recentTrips.map((t) => (
              <li key={t.id} className="flex justify-between gap-4 py-3">
                <div>
                  <p>{t.pickup_address}</p>
                  <p className="text-black/45">→ {t.dropoff_address}</p>
                </div>
                <div className="text-right">
                  <p className="font-medium">{formatPeso(t.fare)}</p>
                  <p className="text-xs text-black/45">{formatDateTime(t.completed_at ?? t.created_at)}</p>
                </div>
              </li>
            ))}
          </ul>
        )}
      </PanelCard>

      <PanelCard title="Activity log">
        {profile.activityLog.length === 0 ? (
          <p className="text-sm text-black/45">No activity logged for this driver.</p>
        ) : (
          <ul className="space-y-2 text-sm">
            {profile.activityLog.map((e, i) => (
              <li key={i} className="flex justify-between gap-4 border-b border-admin-border/60 py-2">
                <span>{e.action}</span>
                <span className="text-black/45">{formatDateTime(e.date)}</span>
              </li>
            ))}
          </ul>
        )}
      </PanelCard>

      {isAdmin ? (
        <PanelCard title="Danger zone">
          <p className="text-sm text-black/55">
            Permanently delete this driver — removes their login, onboarding documents, training
            record, fleet assignment, and profile. Trip history keeps the driver name blank. This
            cannot be undone.
          </p>
          <button
            type="button"
            disabled={busy || deleteBusy}
            onClick={() => {
              setDeleteToken('')
              setDeleteOpen(true)
            }}
            className="mt-4 rounded-xl border border-red-300 bg-red-50 px-4 py-2 text-sm font-medium text-red-800 hover:bg-red-100 disabled:opacity-50"
          >
            Delete driver permanently
          </button>
        </PanelCard>
      ) : null}

      <NameFormModal
        open={editNameOpen}
        busy={nameBusy}
        title="Edit driver name"
        description={`Update the display name for ${profile.email}.`}
        initialName={profile.fullName}
        onSave={handleSaveDriverName}
        onClose={() => setEditNameOpen(false)}
      />

      <ConfirmPermanentDeleteModal
        open={deleteOpen}
        title="Delete driver permanently?"
        description={
          <>
            This removes <strong>{profile.fullName}</strong> ({profile.email}) from Supabase Auth
            and all driver tables. They will need to register again from scratch.
          </>
        }
        confirmLabel="Delete driver"
        confirmToken={profile.email}
        tokenLabel={profile.email}
        tokenValue={deleteToken}
        busy={deleteBusy}
        onTokenChange={setDeleteToken}
        onConfirm={() => void handleDeleteDriver()}
        onClose={() => setDeleteOpen(false)}
      />

      <RequireDocumentsModal
        open={requireDocsOpen}
        driverName={profile.fullName}
        busy={requireDocsBusy}
        error={requireDocsError}
        onConfirm={(reason, docTypes) => void handleRequireDocuments(reason, docTypes)}
        onClose={() => setRequireDocsOpen(false)}
      />
    </div>
  )
}
