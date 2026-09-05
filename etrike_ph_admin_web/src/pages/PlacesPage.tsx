import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { useAuth } from '../hooks/useAuth'
import { listOperators } from '../services/admin'
import { listPlaces, setDriverPlace, setOperatorPlace, setVehiclePlace, upsertPlace } from '../services/places'
import { listDrivers } from '../services/admin'
import { listFleetVehicles } from '../services/fleet'
import type { DriverRow, OperatorRow, PlaceRow } from '../types'
import type { FleetVehicleWithDriver } from '../types/fleet'
import { supabaseErrorMessage } from '../lib/supabaseError'
import { adminInputCls, GhostButton, LoadingState, PanelCard, PrimaryButton } from '../components/ui/adminPageUi'

type FormState = {
  id?: string
  slug: string
  name: string
  display_name: string
  notes: string
  center_lat: string
  center_lng: string
  radius_km: string
  is_active: boolean
}

function emptyForm(): FormState {
  return {
    slug: '',
    name: '',
    display_name: '',
    notes: '',
    center_lat: '14.3922',
    center_lng: '120.9286',
    radius_km: '1.8',
    is_active: true,
  }
}

export function PlacesPage() {
  const { canWriteFare, canWriteFleet, canWriteDrivers, isSuperAdmin, operator } = useAuth()
  const [places, setPlaces] = useState<PlaceRow[]>([])
  const [operators, setOperators] = useState<OperatorRow[]>([])
  const [drivers, setDrivers] = useState<DriverRow[]>([])
  const [vehicles, setVehicles] = useState<FleetVehicleWithDriver[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [form, setForm] = useState<FormState>(() => emptyForm())
  const [editing, setEditing] = useState(false)
  const [saving, setSaving] = useState(false)

  const refresh = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [p, o, d, v] = await Promise.all([
        listPlaces(),
        listOperators(),
        listDrivers(),
        listFleetVehicles().catch(() => [] as FleetVehicleWithDriver[]),
      ])
      setPlaces(p)
      setOperators(o)
      setDrivers(d)
      setVehicles(v)
    } catch (e) {
      setError(supabaseErrorMessage(e, 'Failed to load places'))
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void refresh()
  }, [refresh])

  function startEdit(place: PlaceRow) {
    setEditing(true)
    setForm({
      id: place.id,
      slug: place.slug,
      name: place.name,
      display_name: place.display_name ?? '',
      notes: place.notes ?? '',
      center_lat: String(place.center_lat),
      center_lng: String(place.center_lng),
      radius_km: String(place.radius_km),
      is_active: place.is_active,
    })
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!canWriteFare) return
    setSaving(true)
    setError(null)
    try {
      await upsertPlace({
        id: form.id,
        slug: form.slug,
        name: form.name,
        display_name: form.display_name,
        notes: form.notes,
        center_lat: Number(form.center_lat),
        center_lng: Number(form.center_lng),
        radius_km: Number(form.radius_km),
        is_active: form.is_active,
      })
      setEditing(false)
      setForm(emptyForm())
      await refresh()
    } catch (e2) {
      setError(supabaseErrorMessage(e2, 'Failed to save place'))
    } finally {
      setSaving(false)
    }
  }

  const visiblePlaces = isSuperAdmin || !operator?.place_id
    ? places
    : places.filter((p) => p.id === operator.place_id)

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold text-black/90">Places / villages</h1>
        <p className="mt-1 text-sm text-black/55">
          Each place is a village the app supports. Riders pick their area before booking; the map
          stays inside that coverage. Assign operators and e-trikes to a place so they only serve
          that village. First live area: Malagasang 1-B, Imus.
        </p>
      </div>

      {error ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
      ) : null}

      <PanelCard title="Coverage areas">
        {loading ? (
          <LoadingState />
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead>
                <tr className="border-b border-admin-border text-left text-black/55">
                  <th className="py-2 pr-3">Name</th>
                  <th className="py-2 pr-3">Slug</th>
                  <th className="py-2 pr-3">Radius</th>
                  <th className="py-2 pr-3">Center</th>
                  <th className="py-2 pr-3">Active</th>
                  <th className="py-2 pr-0 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {visiblePlaces.map((p) => (
                  <tr key={p.id} className="border-b border-admin-border last:border-b-0">
                    <td className="py-3 pr-3">
                      <div className="font-medium">{p.display_name || p.name}</div>
                      {p.notes ? <div className="text-xs text-black/50">{p.notes}</div> : null}
                    </td>
                    <td className="py-3 pr-3 font-mono text-xs">{p.slug}</td>
                    <td className="py-3 pr-3">{p.radius_km} km</td>
                    <td className="py-3 pr-3 font-mono text-xs">
                      {p.center_lat.toFixed(4)}, {p.center_lng.toFixed(4)}
                    </td>
                    <td className="py-3 pr-3">{p.is_active ? 'Yes' : 'No'}</td>
                    <td className="py-3 pr-0 text-right">
                      {canWriteFare ? <GhostButton onClick={() => startEdit(p)}>Edit</GhostButton> : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </PanelCard>

      {canWriteFare && isSuperAdmin ? (
        <PanelCard title={editing ? 'Edit place' : 'Add village / client'}>
          <form onSubmit={onSubmit} className="grid grid-cols-1 gap-3 md:grid-cols-2">
            <label className="space-y-1">
              <div className="text-xs font-medium text-black/60">Name</div>
              <input className={adminInputCls} required value={form.name} onChange={(e) => setForm((s) => ({ ...s, name: e.target.value }))} />
            </label>
            <label className="space-y-1">
              <div className="text-xs font-medium text-black/60">Slug</div>
              <input className={adminInputCls} required value={form.slug} onChange={(e) => setForm((s) => ({ ...s, slug: e.target.value }))} placeholder="southwoods-village" />
            </label>
            <label className="space-y-1 md:col-span-2">
              <div className="text-xs font-medium text-black/60">Display name</div>
              <input className={adminInputCls} value={form.display_name} onChange={(e) => setForm((s) => ({ ...s, display_name: e.target.value }))} />
            </label>
            <label className="space-y-1 md:col-span-2">
              <div className="text-xs font-medium text-black/60">Client notes / custom details</div>
              <input className={adminInputCls} value={form.notes} onChange={(e) => setForm((s) => ({ ...s, notes: e.target.value }))} placeholder="Fare, branding, covered streets…" />
            </label>
            <label className="space-y-1">
              <div className="text-xs font-medium text-black/60">Center lat</div>
              <input className={adminInputCls} required value={form.center_lat} onChange={(e) => setForm((s) => ({ ...s, center_lat: e.target.value }))} />
            </label>
            <label className="space-y-1">
              <div className="text-xs font-medium text-black/60">Center lng</div>
              <input className={adminInputCls} required value={form.center_lng} onChange={(e) => setForm((s) => ({ ...s, center_lng: e.target.value }))} />
            </label>
            <label className="space-y-1">
              <div className="text-xs font-medium text-black/60">Radius (km)</div>
              <input className={adminInputCls} required value={form.radius_km} onChange={(e) => setForm((s) => ({ ...s, radius_km: e.target.value }))} />
            </label>
            <label className="flex items-center gap-2 pt-6 text-sm">
              <input type="checkbox" checked={form.is_active} onChange={(e) => setForm((s) => ({ ...s, is_active: e.target.checked }))} />
              Active
            </label>
            <div className="md:col-span-2 flex justify-end gap-2">
              {editing ? <GhostButton onClick={() => { setEditing(false); setForm(emptyForm()) }}>Cancel</GhostButton> : null}
              <PrimaryButton type="submit" disabled={saving}>{saving ? 'Saving…' : 'Save place'}</PrimaryButton>
            </div>
          </form>
        </PanelCard>
      ) : null}

      {canWriteFleet || canWriteDrivers || (canWriteFare && isSuperAdmin) ? (
        <PanelCard title="Assign drivers and fleet to a village">
          <div className="space-y-4 text-sm">
            <p className="text-black/55">
              Each e-trike and driver serves one village. Assigning a unit also moves its current
              driver. Drivers can change their own village in the driver app.
            </p>
            {isSuperAdmin ? operators.map((op) => (
              <div key={op.id} className="flex flex-wrap items-center gap-3 border-b border-admin-border py-2">
                <div className="min-w-48">
                  <div className="font-medium">{op.full_name || op.email}</div>
                  <div className="text-xs text-black/50">{op.role}</div>
                </div>
                <select
                  className={adminInputCls}
                  value={op.place_id ?? ''}
                  onChange={(e) => {
                    const value = e.target.value || null
                    void setOperatorPlace(op.id, value).then(refresh)
                  }}
                >
                  <option value="">All places (super scope)</option>
                  {places.map((p) => (
                    <option key={p.id} value={p.id}>{p.name}</option>
                  ))}
                </select>
              </div>
            )) : null}
            <h3 className="pt-4 font-semibold">Fleet units</h3>
            {vehicles.length === 0 ? (
              <p className="text-black/45">No fleet units yet. Add them on the Fleet page.</p>
            ) : vehicles.map((v) => (
              <div key={v.id} className="flex flex-wrap items-center gap-3 border-b border-admin-border py-2">
                <div className="min-w-48">
                  <div className="font-medium">{v.unit_number} · {v.plate_number}</div>
                  <div className="text-xs text-black/50">{v.assigned_driver_name ?? 'Unassigned unit'}</div>
                </div>
                <select
                  className={adminInputCls}
                  value={v.place_id ?? ''}
                  onChange={(e) => {
                    const value = e.target.value || null
                    void setVehiclePlace(v.id, value).then(refresh)
                  }}
                >
                  <option value="">Unassigned</option>
                  {places.map((p) => (
                    <option key={p.id} value={p.id}>{p.name}</option>
                  ))}
                </select>
              </div>
            ))}
            <h3 className="pt-4 font-semibold">Drivers</h3>
            {drivers.map((d) => (
              <div key={d.id} className="flex flex-wrap items-center gap-3 border-b border-admin-border py-2">
                <div className="min-w-48">
                  <div className="font-medium">{d.full_name || d.email}</div>
                  <div className="text-xs text-black/50">{d.station}</div>
                </div>
                <select
                  className={adminInputCls}
                  value={d.place_id ?? ''}
                  onChange={(e) => {
                    const value = e.target.value || null
                    void setDriverPlace(d.id, value).then(refresh)
                  }}
                >
                  <option value="">Unassigned</option>
                  {places.map((p) => (
                    <option key={p.id} value={p.id}>{p.name}</option>
                  ))}
                </select>
              </div>
            ))}
          </div>
        </PanelCard>
      ) : null}
    </div>
  )
}
