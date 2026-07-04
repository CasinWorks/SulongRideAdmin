import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  assignVehicleToDriver,
  fetchDriverAssignedVehicle,
  listAvailableVehiclesForDriver,
  listDriverAssignments,
  unassignVehicleFromDriver,
} from '../../services/fleet'
import type { FleetVehicle, VehicleAssignmentRow } from '../../types/fleet'
import { ASSIGNMENT_STATUS_LABELS, VEHICLE_STATUS_LABELS } from '../../lib/fleetConstants'
import { formatDateTime } from '../../lib/format'
import { GhostButton, PanelCard, PrimaryButton } from '../ui/adminPageUi'
import { adminInputCls } from '../ui/AdminUi'

type Props = {
  driverId: string
  driverName?: string
  onChanged?: () => void
}

export function DriverVehicleAssignPanel({ driverId, driverName, onChanged }: Props) {
  const [assigned, setAssigned] = useState<FleetVehicle | null>(null)
  const [available, setAvailable] = useState<FleetVehicle[]>([])
  const [history, setHistory] = useState<VehicleAssignmentRow[]>([])
  const [vehicleId, setVehicleId] = useState('')
  const [scheduleFrom, setScheduleFrom] = useState('')
  const [notes, setNotes] = useState('')
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(() => {
    setLoading(true)
    Promise.all([
      fetchDriverAssignedVehicle(driverId),
      listAvailableVehiclesForDriver(driverId),
      listDriverAssignments(driverId),
    ])
      .then(([a, v, h]) => {
        setAssigned(a)
        setAvailable(v)
        setHistory(h)
      })
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load'))
      .finally(() => setLoading(false))
  }, [driverId])

  useEffect(() => {
    load()
  }, [load])

  async function handleAssign() {
    if (!vehicleId) return
    setBusy(true)
    setError(null)
    try {
      await assignVehicleToDriver({
        vehicle_id: vehicleId,
        driver_id: driverId,
        effective_from: scheduleFrom ? new Date(scheduleFrom).toISOString() : undefined,
        notes: notes || undefined,
      })
      setVehicleId('')
      setScheduleFrom('')
      setNotes('')
      load()
      onChanged?.()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Assign failed')
    } finally {
      setBusy(false)
    }
  }

  async function handleUnassign() {
    setBusy(true)
    try {
      await unassignVehicleFromDriver(driverId)
      load()
      onChanged?.()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unassign failed')
    } finally {
      setBusy(false)
    }
  }

  return (
    <PanelCard title="Assigned e-trike">
      {loading ? (
        <p className="text-sm text-black/45">Loading fleet assignment…</p>
      ) : (
        <div className="space-y-4">
          <p className="text-sm text-black/55">
            SulongRide assigns company-owned e-trikes — drivers do not enter plate numbers during
            registration.
            {driverName ? ` Assign a unit for ${driverName}.` : null}
          </p>

          {assigned ? (
            <div className="rounded-xl border border-admin-accent/30 bg-admin-accent/5 p-4">
              <p className="font-semibold text-black/87">
                Unit {assigned.unit_number} · {assigned.plate_number}
              </p>
              <p className="text-sm text-black/55">
                {assigned.model ?? 'E-trike'}
                {assigned.status ? ` · ${VEHICLE_STATUS_LABELS[assigned.status]}` : ''}
              </p>
              {assigned.assigned_at ? (
                <p className="mt-1 text-xs text-black/45">
                  Assigned {formatDateTime(assigned.assigned_at)}
                </p>
              ) : null}
              <div className="mt-3 flex flex-wrap gap-2">
                <Link
                  to={`/fleet/${assigned.id}`}
                  className="text-sm font-medium text-admin-accent hover:underline"
                >
                  Open in fleet →
                </Link>
                <GhostButton disabled={busy} onClick={() => void handleUnassign()}>
                  Unassign
                </GhostButton>
              </div>
            </div>
          ) : (
            <p className="text-sm text-amber-800">No unit assigned yet.</p>
          )}

          <label className="block">
            <span className="text-sm font-medium text-black/70">Assign unit</span>
            <select
              className={adminInputCls}
              value={vehicleId}
              onChange={(e) => setVehicleId(e.target.value)}
            >
              <option value="">Select available unit…</option>
              {available.map((v) => (
                <option key={v.id} value={v.id}>
                  {v.unit_number} · {v.plate_number}
                  {v.model ? ` (${v.model})` : ''}
                </option>
              ))}
            </select>
          </label>
          <label className="block">
            <span className="text-sm font-medium text-black/70">Schedule from (optional)</span>
            <input
              type="datetime-local"
              className={adminInputCls}
              value={scheduleFrom}
              onChange={(e) => setScheduleFrom(e.target.value)}
            />
          </label>
          <PrimaryButton disabled={busy || !vehicleId} onClick={() => void handleAssign()}>
            {scheduleFrom ? 'Schedule assignment' : 'Assign now'}
          </PrimaryButton>

          {history.length > 0 ? (
            <div>
              <p className="mb-2 text-xs font-medium uppercase tracking-wide text-black/45">
                History
              </p>
              <ul className="space-y-1 text-xs text-black/55">
                {history.slice(0, 5).map((h) => (
                  <li key={h.id}>
                    {ASSIGNMENT_STATUS_LABELS[h.status]} · {formatDateTime(h.effective_from)}
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
        </div>
      )}
      {error ? <p className="mt-2 text-sm text-red-700">{error}</p> : null}
    </PanelCard>
  )
}
