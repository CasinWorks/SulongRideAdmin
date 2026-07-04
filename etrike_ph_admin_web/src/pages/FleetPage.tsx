import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Plus, Wrench } from 'lucide-react'
import {
  createVehicle,
  deleteFleetVehiclePermanently,
  listFleetVehicles,
  setVehicleMaintenanceMode,
} from '../services/fleet'
import type { FleetVehicleWithDriver, VehicleFormInput, VehicleStatus } from '../types/fleet'
import { VEHICLE_STATUS_LABELS, vehicleStatusClass } from '../lib/fleetConstants'
import { formatPeso } from '../lib/format'
import {
  ErrorState,
  GhostButton,
  LoadingState,
  PanelCard,
  PrimaryButton,
  adminSearchInputCls,
} from '../components/ui/adminPageUi'
import { adminInputCls } from '../components/ui/AdminUi'
import { ConfirmPermanentDeleteModal } from '../components/ui/ConfirmPermanentDeleteModal'
import { useAuth } from '../hooks/useAuth'

const emptyForm: VehicleFormInput = {
  unit_number: '',
  plate_number: '',
  model: '',
  color: '',
  boundary_fee: 350,
  status: 'available',
  notes: '',
}

export function FleetPage() {
  const { isAdmin } = useAuth()
  const [vehicles, setVehicles] = useState<FleetVehicleWithDriver[]>([])
  const [statusFilter, setStatusFilter] = useState<VehicleStatus | 'all'>('all')
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [showAdd, setShowAdd] = useState(false)
  const [form, setForm] = useState<VehicleFormInput>(emptyForm)
  const [busy, setBusy] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<FleetVehicleWithDriver | null>(null)
  const [deleteToken, setDeleteToken] = useState('')
  const [deleteBusy, setDeleteBusy] = useState(false)

  function load() {
    setLoading(true)
    listFleetVehicles(statusFilter === 'all' ? undefined : statusFilter)
      .then(setVehicles)
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load fleet'))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [statusFilter])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return vehicles
    return vehicles.filter(
      (v) =>
        v.unit_number.toLowerCase().includes(q) ||
        v.plate_number.toLowerCase().includes(q) ||
        (v.model?.toLowerCase().includes(q) ?? false) ||
        (v.assigned_driver_name?.toLowerCase().includes(q) ?? false),
    )
  }, [vehicles, query])

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await createVehicle(form)
      setForm(emptyForm)
      setShowAdd(false)
      load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Create failed')
    } finally {
      setBusy(false)
    }
  }

  async function toggleMaintenance(v: FleetVehicleWithDriver) {
    setBusy(true)
    try {
      await setVehicleMaintenanceMode(v.id, v.status !== 'maintenance')
      load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Update failed')
    } finally {
      setBusy(false)
    }
  }

  async function handleDeleteVehicle() {
    if (!deleteTarget) return
    setDeleteBusy(true)
    setError(null)
    try {
      await deleteFleetVehiclePermanently(deleteTarget.id)
      setDeleteTarget(null)
      setDeleteToken('')
      load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Delete failed')
    } finally {
      setDeleteBusy(false)
    }
  }

  if (loading && vehicles.length === 0) return <LoadingState />
  if (error && vehicles.length === 0) return <ErrorState message={error} />

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-2xl font-semibold">E-trike fleet</h2>
          <p className="mt-1 text-sm text-black/55">
            Company-owned units — add, assign to drivers, and track maintenance. Drivers do not
            register their own plate numbers.
          </p>
        </div>
        <PrimaryButton onClick={() => setShowAdd(true)}>
          <Plus size={16} className="mr-1.5 inline" />
          Add unit
        </PrimaryButton>
      </div>

      {error ? <p className="text-sm text-red-700">{error}</p> : null}

      <div className="flex flex-wrap gap-2">
        {(['all', 'available', 'assigned', 'maintenance', 'retired'] as const).map((s) => (
          <button
            key={s}
            type="button"
            onClick={() => setStatusFilter(s)}
            className={`rounded-xl border px-3 py-2 text-sm font-medium ${
              statusFilter === s
                ? 'border-admin-accent bg-admin-accent/10'
                : 'border-admin-border bg-white text-black/55'
            }`}
          >
            {s === 'all' ? 'All' : VEHICLE_STATUS_LABELS[s]}
          </button>
        ))}
      </div>

      {showAdd ? (
        <PanelCard title="New e-trike unit">
          <form onSubmit={(e) => void handleCreate(e)} className="grid gap-4 sm:grid-cols-2">
            <label className="block">
              <span className="text-sm font-medium text-black/70">Unit number</span>
              <input
                required
                className={adminInputCls}
                value={form.unit_number}
                onChange={(e) => setForm({ ...form, unit_number: e.target.value })}
                placeholder="e.g. ET-001"
              />
            </label>
            <label className="block">
              <span className="text-sm font-medium text-black/70">Plate number</span>
              <input
                required
                className={adminInputCls}
                value={form.plate_number}
                onChange={(e) => setForm({ ...form, plate_number: e.target.value })}
              />
            </label>
            <label className="block">
              <span className="text-sm font-medium text-black/70">Model</span>
              <input
                className={adminInputCls}
                value={form.model ?? ''}
                onChange={(e) => setForm({ ...form, model: e.target.value })}
              />
            </label>
            <label className="block">
              <span className="text-sm font-medium text-black/70">Color</span>
              <input
                className={adminInputCls}
                value={form.color ?? ''}
                onChange={(e) => setForm({ ...form, color: e.target.value })}
              />
            </label>
            <label className="block">
              <span className="text-sm font-medium text-black/70">Daily boundary fee (₱)</span>
              <input
                type="number"
                min={0}
                className={adminInputCls}
                value={form.boundary_fee ?? 0}
                onChange={(e) => setForm({ ...form, boundary_fee: Number(e.target.value) })}
              />
            </label>
            <label className="block sm:col-span-2">
              <span className="text-sm font-medium text-black/70">Notes</span>
              <textarea
                className={`${adminInputCls} min-h-[72px]`}
                value={form.notes ?? ''}
                onChange={(e) => setForm({ ...form, notes: e.target.value })}
              />
            </label>
            <div className="flex gap-2 sm:col-span-2">
              <PrimaryButton disabled={busy} type="submit">
                Save unit
              </PrimaryButton>
              <GhostButton onClick={() => setShowAdd(false)}>Cancel</GhostButton>
            </div>
          </form>
        </PanelCard>
      ) : null}

      <PanelCard
        title={`${filtered.length} unit${filtered.length === 1 ? '' : 's'}`}
        action={
          <input
            type="search"
            placeholder="Search unit, plate, driver…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className={adminSearchInputCls}
          />
        }
      >
        <div className="overflow-x-auto">
          <table className="w-full min-w-[800px] text-left text-sm">
            <thead>
              <tr className="border-b border-admin-border text-black/45">
                <th className="pb-3 pr-4 font-medium">Unit</th>
                <th className="pb-3 pr-4 font-medium">Plate</th>
                <th className="pb-3 pr-4 font-medium">Model</th>
                <th className="pb-3 pr-4 font-medium">Status</th>
                <th className="pb-3 pr-4 font-medium">Driver</th>
                <th className="pb-3 pr-4 font-medium">Boundary</th>
                <th className="pb-3 font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((v) => (
                <tr key={v.id} className="border-b border-admin-border/70">
                  <td className="py-3 pr-4 font-medium">
                    <Link to={`/fleet/${v.id}`} className="text-admin-accent hover:underline">
                      {v.unit_number}
                    </Link>
                  </td>
                  <td className="py-3 pr-4">{v.plate_number}</td>
                  <td className="py-3 pr-4">{v.model ?? '—'}</td>
                  <td className="py-3 pr-4">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-semibold ${vehicleStatusClass(v.status)}`}
                    >
                      {VEHICLE_STATUS_LABELS[v.status]}
                    </span>
                  </td>
                  <td className="py-3 pr-4">
                    {v.assigned_driver_id ? (
                      <Link
                        to={`/drivers/${v.assigned_driver_id}`}
                        className="text-admin-accent hover:underline"
                      >
                        {v.assigned_driver_name ?? 'Driver'}
                      </Link>
                    ) : (
                      '—'
                    )}
                  </td>
                  <td className="py-3 pr-4">{formatPeso(v.boundary_fee)}</td>
                  <td className="py-3">
                    <div className="flex flex-wrap gap-2">
                      <Link
                        to={`/fleet/${v.id}`}
                        className="text-xs font-medium text-admin-accent hover:underline"
                      >
                        Manage
                      </Link>
                      {v.status !== 'retired' ? (
                        <button
                          type="button"
                          disabled={busy}
                          className="inline-flex items-center gap-1 text-xs text-black/55 hover:text-black/80"
                          onClick={() => void toggleMaintenance(v)}
                        >
                          <Wrench size={12} />
                          {v.status === 'maintenance' ? 'Mark available' : 'Maintenance'}
                        </button>
                      ) : null}
                      {isAdmin ? (
                        <button
                          type="button"
                          disabled={busy || deleteBusy}
                          className="text-xs font-medium text-red-700 hover:underline"
                          onClick={() => {
                            setDeleteToken('')
                            setDeleteTarget(v)
                          }}
                        >
                          Delete
                        </button>
                      ) : null}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </PanelCard>

      {deleteTarget ? (
        <ConfirmPermanentDeleteModal
          open
          title="Delete fleet unit permanently?"
          description={
            <>
              This removes unit <strong>{deleteTarget.unit_number}</strong> (
              {deleteTarget.plate_number}) and all maintenance/assignment history.
            </>
          }
          confirmLabel="Delete unit"
          confirmToken={deleteTarget.unit_number}
          tokenLabel={deleteTarget.unit_number}
          tokenValue={deleteToken}
          busy={deleteBusy}
          onTokenChange={setDeleteToken}
          onConfirm={() => void handleDeleteVehicle()}
          onClose={() => {
            setDeleteTarget(null)
            setDeleteToken('')
          }}
        />
      ) : null}
    </div>
  )
}
