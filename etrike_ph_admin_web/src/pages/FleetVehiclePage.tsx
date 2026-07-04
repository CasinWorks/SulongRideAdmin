import { useCallback, useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import {
  addMaintenanceLog,
  assignVehicleToDriver,
  deleteFleetVehiclePermanently,
  fetchFleetVehicle,
  listDriversForAssign,
  listMaintenanceLogs,
  listVehicleAssignments,
  retireVehicle,
  unassignVehicleFromDriver,
  updateVehicle,
} from '../services/fleet'
import type {
  FleetVehicleWithDriver,
  MaintenanceLogInput,
  VehicleAssignmentRow,
  VehicleFormInput,
  VehicleMaintenanceLog,
} from '../types/fleet'
import {
  MAINTENANCE_TYPE_LABELS,
  VEHICLE_STATUS_LABELS,
  vehicleStatusClass,
} from '../lib/fleetConstants'
import { formatDateTime, formatPeso } from '../lib/format'
import {
  ErrorState,
  GhostButton,
  LoadingState,
  PanelCard,
  PrimaryButton,
} from '../components/ui/adminPageUi'
import { adminInputCls } from '../components/ui/AdminUi'
import { ConfirmPermanentDeleteModal } from '../components/ui/ConfirmPermanentDeleteModal'
import { useAuth } from '../hooks/useAuth'

type DriverOption = { id: string; full_name: string; email: string }

export function FleetVehiclePage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { isAdmin } = useAuth()
  const [vehicle, setVehicle] = useState<FleetVehicleWithDriver | null>(null)
  const [assignments, setAssignments] = useState<VehicleAssignmentRow[]>([])
  const [logs, setLogs] = useState<VehicleMaintenanceLog[]>([])
  const [drivers, setDrivers] = useState<DriverOption[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  const [editForm, setEditForm] = useState<Partial<VehicleFormInput>>({})
  const [assignDriverId, setAssignDriverId] = useState('')
  const [assignFrom, setAssignFrom] = useState('')
  const [assignNotes, setAssignNotes] = useState('')
  const [maintForm, setMaintForm] = useState<MaintenanceLogInput>({
    maintenance_type: 'general',
    description: '',
    cost: null,
  })
  const [deleteOpen, setDeleteOpen] = useState(false)
  const [deleteToken, setDeleteToken] = useState('')
  const [deleteBusy, setDeleteBusy] = useState(false)

  const load = useCallback(() => {
    if (!id) return
    setLoading(true)
    Promise.all([
      fetchFleetVehicle(id),
      listVehicleAssignments(id),
      listMaintenanceLogs(id),
      listDriversForAssign(),
    ])
      .then(([v, a, l, d]) => {
        setVehicle(v)
        setAssignments(a)
        setLogs(l)
        setDrivers(d)
        if (v) {
          setEditForm({
            unit_number: v.unit_number,
            plate_number: v.plate_number,
            model: v.model ?? '',
            color: v.color ?? '',
            year_manufactured: v.year_manufactured,
            boundary_fee: v.boundary_fee,
            status: v.status,
            notes: v.notes ?? '',
            next_maintenance_due: v.next_maintenance_due,
          })
        }
      })
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load'))
      .finally(() => setLoading(false))
  }, [id])

  useEffect(() => {
    load()
  }, [load])

  async function handleSaveVehicle() {
    if (!id) return
    setBusy(true)
    try {
      await updateVehicle(id, editForm)
      load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed')
    } finally {
      setBusy(false)
    }
  }

  async function handleAssign() {
    if (!id || !assignDriverId) return
    setBusy(true)
    setError(null)
    try {
      await assignVehicleToDriver({
        vehicle_id: id,
        driver_id: assignDriverId,
        effective_from: assignFrom ? new Date(assignFrom).toISOString() : undefined,
        notes: assignNotes || undefined,
      })
      setAssignDriverId('')
      setAssignFrom('')
      setAssignNotes('')
      load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Assign failed')
    } finally {
      setBusy(false)
    }
  }

  async function handleUnassign() {
    if (!vehicle?.assigned_driver_id) return
    setBusy(true)
    try {
      await unassignVehicleFromDriver(vehicle.assigned_driver_id)
      load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unassign failed')
    } finally {
      setBusy(false)
    }
  }

  async function handleMaintenance(e: React.FormEvent) {
    e.preventDefault()
    if (!id) return
    setBusy(true)
    try {
      await addMaintenanceLog(id, maintForm)
      setMaintForm({ maintenance_type: 'general', description: '', cost: null })
      load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Log failed')
    } finally {
      setBusy(false)
    }
  }

  async function handleRetire() {
    if (!id || !confirm('Retire this unit? It will be unassigned and marked retired.')) return
    setBusy(true)
    try {
      await retireVehicle(id)
      load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Retire failed')
    } finally {
      setBusy(false)
    }
  }

  async function handleDeletePermanently() {
    if (!id) return
    setDeleteBusy(true)
    setError(null)
    try {
      await deleteFleetVehiclePermanently(id)
      navigate('/fleet')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Delete failed')
    } finally {
      setDeleteBusy(false)
    }
  }

  if (!id) return <ErrorState message="Missing vehicle id" />
  if (loading) return <LoadingState />
  if (error && !vehicle) return <ErrorState message={error} />
  if (!vehicle) return <ErrorState message="Vehicle not found" />

  return (
    <div className="space-y-6">
      <div>
        <Link to="/fleet" className="text-sm text-admin-accent hover:underline">
          ← Back to fleet
        </Link>
        <div className="mt-2 flex flex-wrap items-center gap-3">
          <h2 className="text-2xl font-semibold">Unit {vehicle.unit_number}</h2>
          <span
            className={`rounded-full px-2.5 py-0.5 text-xs font-semibold ${vehicleStatusClass(vehicle.status)}`}
          >
            {VEHICLE_STATUS_LABELS[vehicle.status]}
          </span>
        </div>
        <p className="text-sm text-black/55">{vehicle.plate_number}</p>
      </div>

      {error ? <p className="text-sm text-red-700">{error}</p> : null}

      <div className="grid gap-6 lg:grid-cols-2">
        <PanelCard title="Unit details">
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="block">
              <span className="text-sm font-medium text-black/70">Unit number</span>
              <input
                className={adminInputCls}
                value={editForm.unit_number ?? ''}
                onChange={(e) => setEditForm({ ...editForm, unit_number: e.target.value })}
              />
            </label>
            <label className="block">
              <span className="text-sm font-medium text-black/70">Plate</span>
              <input
                className={adminInputCls}
                value={editForm.plate_number ?? ''}
                onChange={(e) => setEditForm({ ...editForm, plate_number: e.target.value })}
              />
            </label>
            <label className="block">
              <span className="text-sm font-medium text-black/70">Model</span>
              <input
                className={adminInputCls}
                value={editForm.model ?? ''}
                onChange={(e) => setEditForm({ ...editForm, model: e.target.value })}
              />
            </label>
            <label className="block">
              <span className="text-sm font-medium text-black/70">Boundary / day</span>
              <input
                type="number"
                className={adminInputCls}
                value={editForm.boundary_fee ?? 0}
                onChange={(e) =>
                  setEditForm({ ...editForm, boundary_fee: Number(e.target.value) })
                }
              />
            </label>
            <label className="block sm:col-span-2">
              <span className="text-sm font-medium text-black/70">Notes</span>
              <textarea
                className={`${adminInputCls} min-h-[72px]`}
                value={editForm.notes ?? ''}
                onChange={(e) => setEditForm({ ...editForm, notes: e.target.value })}
              />
            </label>
          </div>
          <div className="mt-4 flex flex-wrap gap-2">
            <PrimaryButton disabled={busy} onClick={() => void handleSaveVehicle()}>
              Save changes
            </PrimaryButton>
            {vehicle.status !== 'retired' ? (
              <GhostButton disabled={busy} onClick={() => void handleRetire()}>
                Retire unit
              </GhostButton>
            ) : null}
          </div>
        </PanelCard>

        <PanelCard title="Assign to driver">
          {vehicle.assigned_driver_id ? (
            <div className="mb-4 rounded-xl bg-admin-bg p-4 text-sm">
              <p className="font-medium">{vehicle.assigned_driver_name}</p>
              <p className="text-black/55">{vehicle.assigned_driver_email}</p>
              {vehicle.assigned_at ? (
                <p className="mt-1 text-xs text-black/45">
                  Since {formatDateTime(vehicle.assigned_at)}
                </p>
              ) : null}
              <GhostButton disabled={busy} onClick={() => void handleUnassign()}>
                Unassign driver
              </GhostButton>
            </div>
          ) : (
            <p className="mb-3 text-sm text-black/55">No driver currently assigned.</p>
          )}
          <label className="block">
            <span className="text-sm font-medium text-black/70">Driver</span>
            <select
              className={adminInputCls}
              value={assignDriverId}
              onChange={(e) => setAssignDriverId(e.target.value)}
            >
              <option value="">Select driver…</option>
              {drivers.map((d) => (
                <option key={d.id} value={d.id}>
                  {d.full_name} · {d.email}
                </option>
              ))}
            </select>
          </label>
          <label className="mt-3 block">
            <span className="text-sm font-medium text-black/70">
              Effective from (optional — schedule future assignment)
            </span>
            <input
              type="datetime-local"
              className={adminInputCls}
              value={assignFrom}
              onChange={(e) => setAssignFrom(e.target.value)}
            />
          </label>
          <label className="mt-3 block">
            <span className="text-sm font-medium text-black/70">Notes</span>
            <input
              className={adminInputCls}
              value={assignNotes}
              onChange={(e) => setAssignNotes(e.target.value)}
            />
          </label>
          <PrimaryButton disabled={busy || !assignDriverId} onClick={() => void handleAssign()}>
            {assignFrom ? 'Schedule assignment' : 'Assign now'}
          </PrimaryButton>
        </PanelCard>
      </div>

      <PanelCard title="Maintenance log">
        <form onSubmit={(e) => void handleMaintenance(e)} className="mb-6 grid gap-3 sm:grid-cols-2">
          <label className="block">
            <span className="text-sm font-medium text-black/70">Type</span>
            <select
              className={adminInputCls}
              value={maintForm.maintenance_type}
              onChange={(e) =>
                setMaintForm({
                  ...maintForm,
                  maintenance_type: e.target.value as MaintenanceLogInput['maintenance_type'],
                })
              }
            >
              {Object.entries(MAINTENANCE_TYPE_LABELS).map(([k, label]) => (
                <option key={k} value={k}>
                  {label}
                </option>
              ))}
            </select>
          </label>
          <label className="block">
            <span className="text-sm font-medium text-black/70">Cost (₱)</span>
            <input
              type="number"
              className={adminInputCls}
              value={maintForm.cost ?? ''}
              onChange={(e) =>
                setMaintForm({
                  ...maintForm,
                  cost: e.target.value ? Number(e.target.value) : null,
                })
              }
            />
          </label>
          <label className="block sm:col-span-2">
            <span className="text-sm font-medium text-black/70">Description</span>
            <textarea
              required
              className={`${adminInputCls} min-h-[72px]`}
              value={maintForm.description}
              onChange={(e) => setMaintForm({ ...maintForm, description: e.target.value })}
            />
          </label>
          <PrimaryButton disabled={busy} type="submit">
            Add log entry
          </PrimaryButton>
        </form>
        {logs.length === 0 ? (
          <p className="text-sm text-black/45">No maintenance recorded yet.</p>
        ) : (
          <ul className="divide-y divide-admin-border text-sm">
            {logs.map((log) => (
              <li key={log.id} className="py-3">
                <p className="font-medium">
                  {MAINTENANCE_TYPE_LABELS[log.maintenance_type]} — {log.description}
                </p>
                <p className="text-black/45">
                  {formatDateTime(log.performed_at)}
                  {log.cost != null ? ` · ${formatPeso(log.cost)}` : ''}
                </p>
              </li>
            ))}
          </ul>
        )}
      </PanelCard>

      <PanelCard title="Assignment history">
        {assignments.length === 0 ? (
          <p className="text-sm text-black/45">No assignments yet.</p>
        ) : (
          <ul className="divide-y divide-admin-border text-sm">
            {assignments.map((a) => (
              <li key={a.id} className="flex justify-between gap-4 py-2">
                <span>
                  Driver {a.driver_id.slice(0, 8)}… · {a.status}
                </span>
                <span className="text-black/45">{formatDateTime(a.effective_from)}</span>
              </li>
            ))}
          </ul>
        )}
      </PanelCard>

      {isAdmin ? (
        <PanelCard title="Danger zone">
          <p className="text-sm text-black/55">
            Permanently delete unit <strong>{vehicle.unit_number}</strong> — removes assignment
            history and maintenance logs. Payroll records keep the unit reference cleared. Use
            &quot;Retire&quot; instead if you only want to take a unit out of service.
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
            Delete unit permanently
          </button>
        </PanelCard>
      ) : null}

      <ConfirmPermanentDeleteModal
        open={deleteOpen}
        title="Delete fleet unit permanently?"
        description={
          <>
            This removes unit <strong>{vehicle.unit_number}</strong> ({vehicle.plate_number}) and
            all maintenance and assignment history tied to this record.
          </>
        }
        confirmLabel="Delete unit"
        confirmToken={vehicle.unit_number}
        tokenLabel={vehicle.unit_number}
        tokenValue={deleteToken}
        busy={deleteBusy}
        onTokenChange={setDeleteToken}
        onConfirm={() => void handleDeletePermanently()}
        onClose={() => setDeleteOpen(false)}
      />
    </div>
  )
}
