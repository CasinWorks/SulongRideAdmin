import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { ChevronLeft, ChevronRight, Upload } from 'lucide-react'
import { listDrivers, fetchDriver } from '../services/admin'
import {
  approveOnboarding,
  fetchOnboardingBundle,
  listAvailableVehicles,
  rejectOnboarding,
  saveDraftStep,
  saveEmployment,
  savePersonalInfo,
  uploadDocument,
} from '../services/onboarding'
import type { DriverRow } from '../types'
import type { DriverDocumentRow, EmploymentForm, PersonalInfoForm } from '../types/onboarding'
import { driverDisplayName } from '../lib/format'
import {
  DOCUMENT_LABELS,
  DOCUMENTS_BY_STEP,
  DEFAULT_STATION,
  EMPLOYMENT_TYPES,
  ONBOARDING_STEP_LABELS,
  SHIFT_OPTIONS,
} from '../lib/onboardingConstants'
import type { DocumentTypeId } from '../lib/onboardingConstants'
import {
  ErrorState,
  GhostButton,
  LoadingState,
  PanelCard,
  PrimaryButton,
} from '../components/ui/adminPageUi'
import { adminInputCls } from '../components/ui/AdminUi'
import {
  DocumentInlinePreview,
  DriverDocumentsPanel,
} from '../components/onboarding/DriverDocumentsPanel'

const WIZARD_STEPS = ONBOARDING_STEP_LABELS.length - 1

function CompanyFleetNote({ compact = false }: { compact?: boolean }) {
  return (
    <div
      className={`rounded-xl border border-admin-accent/25 bg-admin-accent/5 ${compact ? 'p-3' : 'p-4'}`}
    >
      <p className="text-sm font-medium text-black/87">Company-owned e-trike fleet</p>
      <p className="mt-1 text-sm text-black/55">
        SulongRide provides the e-trike — drivers do not submit OR/CR. Assign a fleet unit in the
        Employment step; the driver sees their unit ID in the app after assignment.
      </p>
    </div>
  )
}

function StepIndicator({ current }: { current: number }) {
  return (
    <ol className="mb-6 flex flex-wrap gap-2">
      {ONBOARDING_STEP_LABELS.map((label, index) => {
        const active = index === current
        const done = index < current
        return (
          <li
            key={label}
            className={`rounded-full px-3 py-1 text-xs font-medium ${
              active
                ? 'bg-admin-accent text-white'
                : done
                  ? 'bg-green-100 text-green-800'
                  : 'bg-admin-bg text-black/45'
            }`}
          >
            {label}
          </li>
        )
      })}
    </ol>
  )
}

function DocumentUploadField({
  docType,
  existing,
  busy,
  onUpload,
}: {
  docType: DocumentTypeId
  existing: DriverDocumentRow | undefined
  busy: boolean
  onUpload: (file: File, expiry?: string) => Promise<void>
}) {
  const [expiry, setExpiry] = useState(existing?.expiry_date ?? '')

  return (
    <div className="rounded-xl border border-admin-border bg-white p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="font-medium text-black/87">{DOCUMENT_LABELS[docType]}</p>
          {existing?.file_name ? (
            <p className="mt-1 text-xs text-green-700">Uploaded: {existing.file_name}</p>
          ) : (
            <p className="mt-1 text-xs text-black/45">Required</p>
          )}
          <DocumentInlinePreview
            docType={docType}
            fileUrl={existing?.file_url}
            fileName={existing?.file_name}
          />
        </div>
        <label className="inline-flex cursor-pointer items-center gap-2 rounded-xl border border-admin-border bg-admin-bg px-3 py-2 text-sm font-medium text-black/70 hover:bg-white">
          <Upload size={16} />
          {busy ? 'Uploading…' : existing ? 'Replace' : 'Upload'}
          <input
            type="file"
            accept="image/*,.pdf"
            className="hidden"
            disabled={busy}
            onChange={(e) => {
              const file = e.target.files?.[0]
              if (file) void onUpload(file, expiry || undefined)
              e.target.value = ''
            }}
          />
        </label>
      </div>
      {docType !== 'psa_birth' ? (
        <label className="mt-3 block text-xs text-black/55">
          Expiry date (optional)
          <input
            type="date"
            value={expiry}
            onChange={(e) => setExpiry(e.target.value)}
            className={`${adminInputCls} mt-1 py-2 text-sm`}
          />
        </label>
      ) : null}
    </div>
  )
}

export function DriverOnboardingPage() {
  const { driverId: routeDriverId } = useParams<{ driverId?: string }>()
  const navigate = useNavigate()
  const [step, setStep] = useState(routeDriverId ? 1 : 0)
  const [selectedDriver, setSelectedDriver] = useState<DriverRow | null>(null)
  const [pendingDrivers, setPendingDrivers] = useState<DriverRow[]>([])
  const [vehicles, setVehicles] = useState<Awaited<ReturnType<typeof listAvailableVehicles>>>([])
  const [documents, setDocuments] = useState<DriverDocumentRow[]>([])
  const [checklistPercent, setChecklistPercent] = useState(0)
  const [pipelineStage, setPipelineStage] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [uploadBusy, setUploadBusy] = useState<DocumentTypeId | null>(null)
  const [rejectReason, setRejectReason] = useState('')

  const [personal, setPersonal] = useState<PersonalInfoForm>({
    first_name: '',
    last_name: '',
    contact: '',
    email: '',
    emergency_contact: '',
  })

  const [employment, setEmployment] = useState<EmploymentForm>({
    vehicle_id: '',
    employment_type: 'contractual',
    shift_schedule: SHIFT_OPTIONS[0],
    start_date: new Date().toISOString().slice(0, 10),
    station: DEFAULT_STATION,
  })

  const selectedDriverId = selectedDriver?.id ?? routeDriverId ?? ''

  const activeDriver = selectedDriver

  const docMap = useMemo(() => {
    const map = new Map<DocumentTypeId, DriverDocumentRow>()
    for (const doc of documents) map.set(doc.doc_type, doc)
    return map
  }, [documents])

  const loadBundle = useCallback(async (driverId: string, driver?: DriverRow | null) => {
    const bundle = await fetchOnboardingBundle(driverId)
    setDocuments(bundle.documents)
    setChecklistPercent(bundle.checklist_percent)
    setPipelineStage(bundle.pipeline?.stage_label ?? null)

    const info = bundle.draft?.personal_info ?? {}
    const emp = bundle.draft?.employment ?? {}
    setPersonal({
      first_name: String(info.first_name ?? driver?.full_name?.split(' ')[0] ?? ''),
      last_name: String(
        info.last_name ?? driver?.full_name?.split(' ').slice(1).join(' ') ?? '',
      ),
      contact: String(info.contact ?? driver?.phone ?? ''),
      email: String(info.email ?? driver?.email ?? ''),
      emergency_contact: String(
        info.emergency_contact ?? driver?.emergency_contact ?? '',
      ),
    })
    setEmployment({
      vehicle_id: String(emp.vehicle_id ?? ''),
      employment_type: String(emp.type ?? driver?.employment_type ?? 'contractual'),
      shift_schedule: String(emp.shift ?? driver?.shift_schedule ?? SHIFT_OPTIONS[0]),
      start_date: String(
        emp.start_date ?? driver?.start_date ?? new Date().toISOString().slice(0, 10),
      ),
      station: String(emp.station ?? driver?.station ?? DEFAULT_STATION),
    })
    if (bundle.draft?.current_step && bundle.draft.current_step > 0) {
      setStep(Math.min(bundle.draft.current_step, WIZARD_STEPS))
    }
  }, [])

  useEffect(() => {
    let cancelled = false

    async function load() {
      setLoading(true)
      setError(null)
      try {
        const [drivers, driver] = await Promise.all([
          listDrivers('pending'),
          routeDriverId ? fetchDriver(routeDriverId) : Promise.resolve(null),
        ])
        if (cancelled) return

        setPendingDrivers(drivers)

        if (routeDriverId) {
          if (!driver) {
            setSelectedDriver(null)
            setError('Driver not found or you do not have access.')
            setStep(0)
            return
          }
          setSelectedDriver(driver)
          setStep(1)
          const vehicleRows = await listAvailableVehicles(routeDriverId)
          if (cancelled) return
          setVehicles(vehicleRows)
          await loadBundle(routeDriverId, driver)
        } else {
          setSelectedDriver(null)
          setStep(0)
        }
      } catch (e) {
        if (!cancelled) {
          setError(e instanceof Error ? e.message : 'Failed to load onboarding')
        }
      } finally {
        if (!cancelled) setLoading(false)
      }
    }

    void load()
    return () => {
      cancelled = true
    }
  }, [routeDriverId, loadBundle])

  useEffect(() => {
    if (!selectedDriverId || step === 0) return
    void listAvailableVehicles(selectedDriverId).then(setVehicles)
  }, [selectedDriverId])

  function startOnboarding(driver: DriverRow) {
    navigate(`/drivers/onboarding/${driver.id}`)
  }

  async function handleSavePersonal() {
    if (!selectedDriverId) return
    setBusy(true)
    setError(null)
    try {
      await savePersonalInfo(selectedDriverId, personal)
      await loadBundle(selectedDriverId, activeDriver)
      setStep(2)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed')
    } finally {
      setBusy(false)
    }
  }

  async function handleDocUpload(docType: DocumentTypeId, file: File, expiry?: string) {
    if (!selectedDriverId) return
    setUploadBusy(docType)
    setError(null)
    try {
      await uploadDocument(selectedDriverId, docType, file, expiry)
      await loadBundle(selectedDriverId, activeDriver)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Upload failed')
    } finally {
      setUploadBusy(null)
    }
  }

  async function handleSaveEmployment() {
    if (!selectedDriverId) return
    setBusy(true)
    setError(null)
    try {
      await saveEmployment(selectedDriverId, employment)
      await loadBundle(selectedDriverId, activeDriver)
      setStep(6)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed')
    } finally {
      setBusy(false)
    }
  }

  async function handleApprove() {
    if (!selectedDriverId) return
    setBusy(true)
    setError(null)
    try {
      await approveOnboarding(selectedDriverId)
      navigate('/approved', { replace: true })
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Approval failed')
    } finally {
      setBusy(false)
    }
  }

  async function handleReject() {
    if (!selectedDriverId) return
    setBusy(true)
    setError(null)
    try {
      await rejectOnboarding(selectedDriverId, rejectReason)
      navigate('/revoked', { replace: true })
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Reject failed')
    } finally {
      setBusy(false)
    }
  }

  async function goToStep(next: number) {
    if (!selectedDriverId) return
    setStep(next)
    await saveDraftStep(selectedDriverId, next)
  }

  if (loading) return <LoadingState label="Loading onboarding…" />
  if (error && step === 0 && pendingDrivers.length === 0) return <ErrorState message={error} />
  if (routeDriverId && step >= 1 && !activeDriver) {
    return <ErrorState message={error ?? 'Driver not found or you do not have access.'} />
  }

  return (
    <div className="space-y-6">
      <div>
        <Link to="/pending" className="text-sm text-admin-accent hover:underline">
          ← Back to pending drivers
        </Link>
        <h2 className="mt-2 text-2xl font-semibold">Driver onboarding</h2>
        <p className="text-sm text-black/55">
          Complete registration, upload compliance documents, assign a unit, and approve for the
          Carmona fleet.
        </p>
      </div>

      <StepIndicator current={step} />

      {error ? (
        <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>
      ) : null}

      {step === 0 ? (
        <PanelCard title="Select pending applicant">
          {pendingDrivers.length === 0 ? (
            <p className="py-8 text-center text-black/45">
              No pending driver applications. Drivers appear here after they register in the driver
              app.
            </p>
          ) : (
            <ul className="divide-y divide-admin-border">
              {pendingDrivers.map((d) => (
                <li key={d.id} className="flex flex-wrap items-center justify-between gap-4 py-4">
                  <div>
                    <p className="font-medium">{driverDisplayName(d)}</p>
                    <p className="text-sm text-black/55">{d.email}</p>
                    <p className="text-xs text-black/45">
                      {d.trike_plate_number ?? 'No plate yet'} · Applied{' '}
                      {d.created_at ? new Date(d.created_at).toLocaleDateString() : '—'}
                    </p>
                  </div>
                  <PrimaryButton onClick={() => startOnboarding(d)}>Start onboarding</PrimaryButton>
                </li>
              ))}
            </ul>
          )}
        </PanelCard>
      ) : null}

      {step >= 1 && activeDriver ? (
        <PanelCard
          title={`Onboarding: ${driverDisplayName(activeDriver)}`}
          action={
            pipelineStage ? (
              <span className="rounded-full bg-admin-bg px-3 py-1 text-xs font-medium text-black/55">
                {pipelineStage} · Checklist {checklistPercent}%
              </span>
            ) : null
          }
        >
          {step === 1 ? (
            <div className="space-y-4">
              <div className="grid gap-4 sm:grid-cols-2">
                <label className="block">
                  <span className="text-sm font-medium text-black/70">First name</span>
                  <input
                    className={adminInputCls}
                    value={personal.first_name}
                    onChange={(e) => setPersonal({ ...personal, first_name: e.target.value })}
                  />
                </label>
                <label className="block">
                  <span className="text-sm font-medium text-black/70">Last name</span>
                  <input
                    className={adminInputCls}
                    value={personal.last_name}
                    onChange={(e) => setPersonal({ ...personal, last_name: e.target.value })}
                  />
                </label>
                <label className="block">
                  <span className="text-sm font-medium text-black/70">Contact (09XXXXXXXXX)</span>
                  <input
                    className={adminInputCls}
                    value={personal.contact}
                    onChange={(e) => setPersonal({ ...personal, contact: e.target.value })}
                  />
                </label>
                <label className="block">
                  <span className="text-sm font-medium text-black/70">Email</span>
                  <input
                    type="email"
                    readOnly
                    className={`${adminInputCls} bg-admin-bg/60`}
                    value={personal.email}
                  />
                </label>
                <label className="block sm:col-span-2">
                  <span className="text-sm font-medium text-black/70">Emergency contact</span>
                  <input
                    className={adminInputCls}
                    value={personal.emergency_contact}
                    onChange={(e) =>
                      setPersonal({ ...personal, emergency_contact: e.target.value })
                    }
                  />
                </label>
              </div>
              {(DOCUMENTS_BY_STEP[1] ?? []).map((docType) => (
                <DocumentUploadField
                  key={docType}
                  docType={docType}
                  existing={docMap.get(docType)}
                  busy={uploadBusy === docType}
                  onUpload={(file, expiry) => handleDocUpload(docType, file, expiry)}
                />
              ))}
              <PrimaryButton disabled={busy} onClick={() => void handleSavePersonal()}>
                Save & continue
              </PrimaryButton>
            </div>
          ) : null}

          {[2, 3, 4].includes(step) ? (
            <div className="space-y-4">
              {step === 2 ? <CompanyFleetNote /> : null}
              {(DOCUMENTS_BY_STEP[step] ?? []).map((docType) => (
                <DocumentUploadField
                  key={docType}
                  docType={docType}
                  existing={docMap.get(docType)}
                  busy={uploadBusy === docType}
                  onUpload={(file, expiry) => handleDocUpload(docType, file, expiry)}
                />
              ))}
              <div className="flex gap-2 pt-2">
                <GhostButton onClick={() => void goToStep(step - 1)}>
                  <ChevronLeft size={16} className="mr-1 inline" />
                  Back
                </GhostButton>
                <PrimaryButton onClick={() => void goToStep(step + 1)}>
                  Continue
                  <ChevronRight size={16} className="ml-1 inline" />
                </PrimaryButton>
              </div>
            </div>
          ) : null}

          {step === 5 ? (
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="sm:col-span-2">
                <CompanyFleetNote compact />
              </div>
              <label className="block sm:col-span-2">
                <span className="text-sm font-medium text-black/70">Assigned e-trike unit</span>
                <p className="mb-2 text-xs text-black/45">
                  Required before approval — links this driver to a company-owned unit (replaces OR/CR).
                </p>
                <select
                  className={adminInputCls}
                  value={employment.vehicle_id}
                  onChange={(e) => setEmployment({ ...employment, vehicle_id: e.target.value })}
                >
                  <option value="">Select unit…</option>
                  {vehicles.map((v) => (
                    <option key={v.id} value={v.id}>
                      {v.unit_number} · {v.plate_number}
                      {v.model ? ` (${v.model})` : ''}
                    </option>
                  ))}
                </select>
              </label>
              <label className="block">
                <span className="text-sm font-medium text-black/70">Employment type</span>
                <select
                  className={adminInputCls}
                  value={employment.employment_type}
                  onChange={(e) =>
                    setEmployment({ ...employment, employment_type: e.target.value })
                  }
                >
                  {EMPLOYMENT_TYPES.map((t) => (
                    <option key={t.value} value={t.value}>
                      {t.label}
                    </option>
                  ))}
                </select>
              </label>
              <label className="block">
                <span className="text-sm font-medium text-black/70">Shift</span>
                <select
                  className={adminInputCls}
                  value={employment.shift_schedule}
                  onChange={(e) =>
                    setEmployment({ ...employment, shift_schedule: e.target.value })
                  }
                >
                  {SHIFT_OPTIONS.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </select>
              </label>
              <label className="block">
                <span className="text-sm font-medium text-black/70">Start date</span>
                <input
                  type="date"
                  className={adminInputCls}
                  value={employment.start_date}
                  onChange={(e) => setEmployment({ ...employment, start_date: e.target.value })}
                />
              </label>
              <label className="block">
                <span className="text-sm font-medium text-black/70">Station</span>
                <input
                  className={adminInputCls}
                  value={employment.station}
                  onChange={(e) => setEmployment({ ...employment, station: e.target.value })}
                />
              </label>
              <div className="flex gap-2 sm:col-span-2">
                <GhostButton onClick={() => void goToStep(4)}>Back</GhostButton>
                <PrimaryButton disabled={busy} onClick={() => void handleSaveEmployment()}>
                  Save & review
                </PrimaryButton>
              </div>
            </div>
          ) : null}

          {step === 6 ? (
            <div className="space-y-4">
              <p className="text-sm text-black/55">
                Review all uploaded documents below before approving or rejecting this application.
              </p>
              <label className="block">
                <span className="text-sm font-medium text-black/70">Rejection reason (optional)</span>
                <textarea
                  className={`${adminInputCls} min-h-[80px]`}
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  placeholder="Required if rejecting application"
                />
              </label>
              <div className="flex flex-wrap gap-2">
                <GhostButton onClick={() => void goToStep(5)}>Back</GhostButton>
                <PrimaryButton disabled={busy} onClick={() => void handleApprove()}>
                  Approve driver
                </PrimaryButton>
                <GhostButton disabled={busy} onClick={() => void handleReject()}>
                  Reject application
                </GhostButton>
              </div>
            </div>
          ) : null}
        </PanelCard>
      ) : null}

      {step >= 2 && activeDriver ? (
        <DriverDocumentsPanel documents={documents} checklistPercent={checklistPercent} />
      ) : null}
    </div>
  )
}
