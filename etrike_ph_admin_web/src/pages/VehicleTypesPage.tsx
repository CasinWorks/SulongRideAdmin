import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react'
import { useAuth } from '../hooks/useAuth'
import type { VehicleTypeRow } from '../types'
import { deleteVehicleType, listVehicleTypes, setVehicleTypeActive, upsertVehicleType } from '../services/vehicleTypes'
import { formatDateTime } from '../lib/format'
import { supabaseErrorMessage } from '../lib/supabaseError'
import { adminInputCls, GhostButton, LoadingState, PanelCard, PrimaryButton } from '../components/ui/adminPageUi'

const inputCls = adminInputCls

type FormState = {
  id: string
  name: string
  description: string
  icon: string
  eta_minutes: string
  sort_order: string
  is_active: boolean
}

function emptyForm(): FormState {
  return {
    id: '',
    name: '',
    description: '',
    icon: '🛺',
    eta_minutes: '3',
    sort_order: '0',
    is_active: true,
  }
}

export function VehicleTypesPage() {
  const { canWriteFleet } = useAuth()
  const [rows, setRows] = useState<VehicleTypeRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [form, setForm] = useState<FormState>(() => emptyForm())

  const editing = useMemo(() => rows.find((r) => r.id === editingId) ?? null, [rows, editingId])

  const refresh = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      setRows(await listVehicleTypes())
    } catch (e) {
      setError(supabaseErrorMessage(e))
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    refresh()
  }, [refresh])

  function startCreate() {
    setEditingId('__new__')
    setForm(emptyForm())
  }

  function startEdit(row: VehicleTypeRow) {
    setEditingId(row.id)
    setForm({
      id: row.id,
      name: row.name,
      description: row.description,
      icon: row.icon || '🛺',
      eta_minutes: String(row.eta_minutes ?? 3),
      sort_order: String(row.sort_order ?? 0),
      is_active: row.is_active,
    })
  }

  function cancelEdit() {
    setEditingId(null)
    setForm(emptyForm())
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!canWriteFleet) return
    setSaving(true)
    setError(null)
    try {
      await upsertVehicleType({
        id: form.id.trim(),
        name: form.name.trim(),
        description: form.description.trim(),
        icon: form.icon.trim() || '🛺',
        eta_minutes: Number(form.eta_minutes || 3),
        sort_order: Number(form.sort_order || 0),
        is_active: form.is_active,
      })
      await refresh()
      cancelEdit()
    } catch (e2) {
      setError(supabaseErrorMessage(e2))
    } finally {
      setSaving(false)
    }
  }

  async function toggleActive(row: VehicleTypeRow) {
    if (!canWriteFleet) return
    setError(null)
    try {
      await setVehicleTypeActive(row.id, !row.is_active)
      await refresh()
    } catch (e) {
      setError(supabaseErrorMessage(e))
    }
  }

  async function onDelete(row: VehicleTypeRow) {
    if (!canWriteFleet) return
    const ok = window.confirm(`Delete vehicle type \"${row.name}\" (${row.id})?`)
    if (!ok) return
    setError(null)
    try {
      await deleteVehicleType(row.id)
      await refresh()
    } catch (e) {
      setError(supabaseErrorMessage(e))
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold text-black/90">Vehicle types</h1>
          <p className="mt-1 text-sm text-black/55">
            Enable/disable which eco-trike options riders can see. Disabled types won&apos;t appear in the Rider app.
          </p>
        </div>
        {canWriteFleet ? (
          <PrimaryButton label="Add vehicle type" onPressed={startCreate} />
        ) : null}
      </div>

      {error ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
      ) : null}

      <PanelCard>
        {loading ? (
          <LoadingState />
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead>
                <tr className="border-b border-admin-border text-left text-black/55">
                  <th className="py-2 pr-3">Active</th>
                  <th className="py-2 pr-3">ID</th>
                  <th className="py-2 pr-3">Name</th>
                  <th className="py-2 pr-3">Icon</th>
                  <th className="py-2 pr-3">ETA (min)</th>
                  <th className="py-2 pr-3">Sort</th>
                  <th className="py-2 pr-3">Updated</th>
                  <th className="py-2 pr-0 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id} className="border-b border-admin-border last:border-b-0">
                    <td className="py-3 pr-3">
                      <button
                        type="button"
                        disabled={!canWriteFleet}
                        onClick={() => toggleActive(r)}
                        className={[
                          'inline-flex items-center rounded-full px-2 py-1 text-xs font-medium',
                          r.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600',
                          !canWriteFleet ? 'opacity-60' : 'hover:opacity-90',
                        ].join(' ')}
                      >
                        {r.is_active ? 'Enabled' : 'Disabled'}
                      </button>
                    </td>
                    <td className="py-3 pr-3 font-mono text-xs text-black/70">{r.id}</td>
                    <td className="py-3 pr-3">
                      <div className="font-medium text-black/85">{r.name}</div>
                      {r.description ? <div className="text-xs text-black/50">{r.description}</div> : null}
                    </td>
                    <td className="py-3 pr-3">{r.icon || '🛺'}</td>
                    <td className="py-3 pr-3">{r.eta_minutes}</td>
                    <td className="py-3 pr-3">{r.sort_order}</td>
                    <td className="py-3 pr-3 text-xs text-black/55">{r.updated_at ? formatDateTime(r.updated_at) : '—'}</td>
                    <td className="py-3 pr-0 text-right">
                      <div className="flex justify-end gap-2">
                        <GhostButton label="Edit" onPressed={() => startEdit(r)} />
                        {canWriteFleet ? <GhostButton label="Delete" onPressed={() => onDelete(r)} /> : null}
                      </div>
                    </td>
                  </tr>
                ))}
                {rows.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="py-10 text-center text-sm text-black/55">
                      No vehicle types found. Run the Supabase script to seed defaults.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        )}
      </PanelCard>

      {editingId ? (
        <PanelCard>
          <form onSubmit={onSubmit} className="space-y-4">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h2 className="text-base font-semibold text-black/85">
                  {editingId === '__new__' ? 'Add vehicle type' : `Edit ${editing?.name ?? editingId}`}
                </h2>
                <p className="mt-1 text-xs text-black/55">
                  The Rider app shows only <span className="font-medium">Enabled</span> types.
                </p>
              </div>
              <GhostButton label="Cancel" onPressed={cancelEdit} />
            </div>

            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <label className="space-y-1">
                <div className="text-xs font-medium text-black/60">ID (stable key)</div>
                <input
                  className={inputCls}
                  value={form.id}
                  onChange={(e) => setForm((s) => ({ ...s, id: e.target.value }))}
                  placeholder="bike"
                  disabled={saving || (editingId !== '__new__')}
                  required
                />
              </label>
              <label className="space-y-1">
                <div className="text-xs font-medium text-black/60">Name</div>
                <input
                  className={inputCls}
                  value={form.name}
                  onChange={(e) => setForm((s) => ({ ...s, name: e.target.value }))}
                  placeholder="EcoTrike Commuter"
                  disabled={saving}
                  required
                />
              </label>
              <label className="space-y-1 md:col-span-2">
                <div className="text-xs font-medium text-black/60">Description</div>
                <input
                  className={inputCls}
                  value={form.description}
                  onChange={(e) => setForm((s) => ({ ...s, description: e.target.value }))}
                  placeholder="Standard electric tricycle with comfortable seating"
                  disabled={saving}
                />
              </label>
              <label className="space-y-1">
                <div className="text-xs font-medium text-black/60">Icon</div>
                <input
                  className={inputCls}
                  value={form.icon}
                  onChange={(e) => setForm((s) => ({ ...s, icon: e.target.value }))}
                  placeholder="🛺"
                  disabled={saving}
                />
              </label>
              <label className="space-y-1">
                <div className="text-xs font-medium text-black/60">ETA minutes</div>
                <input
                  className={inputCls}
                  type="number"
                  min={1}
                  value={form.eta_minutes}
                  onChange={(e) => setForm((s) => ({ ...s, eta_minutes: e.target.value }))}
                  disabled={saving}
                />
              </label>
              <label className="space-y-1">
                <div className="text-xs font-medium text-black/60">Sort order</div>
                <input
                  className={inputCls}
                  type="number"
                  value={form.sort_order}
                  onChange={(e) => setForm((s) => ({ ...s, sort_order: e.target.value }))}
                  disabled={saving}
                />
              </label>
              <label className="flex items-center gap-2 pt-6 text-sm text-black/70">
                <input
                  type="checkbox"
                  checked={form.is_active}
                  onChange={(e) => setForm((s) => ({ ...s, is_active: e.target.checked }))}
                  disabled={saving}
                />
                Enabled
              </label>
            </div>

            {canWriteFleet ? (
              <div className="flex items-center justify-end gap-2">
                <PrimaryButton label={saving ? 'Saving…' : 'Save'} onPressed={() => {}} type="submit" />
              </div>
            ) : (
              <div className="text-sm text-black/55">Read-only access.</div>
            )}
          </form>
        </PanelCard>
      ) : null}
    </div>
  )
}

