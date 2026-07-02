import { useCallback, useEffect, useState } from 'react'
import {
  createFareSchedule,
  deactivateFareSchedule,
  DEFAULT_FARE,
  fetchActiveFare,
  fetchEffectiveFare,
  initializeDefaultFare,
  listFareSchedules,
  updateActiveFare,
  updateFareSchedule,
} from '../services/admin'
import type { EffectiveFare, FareConfig, FareSchedule, FareScheduleType } from '../types'
import { formatDateTime, formatPeso } from '../lib/format'
import { supabaseErrorMessage } from '../lib/supabaseError'
import { GhostButton, LoadingState, PanelCard, PrimaryButton } from '../components/ui/AdminUi'

const inputCls =
  'mt-1 w-full rounded-xl border border-admin-border px-3 py-2.5 text-sm outline-none focus:border-admin-accent'

type ScheduleStatus = 'upcoming' | 'active' | 'ended' | 'inactive'

function scheduleStatus(s: FareSchedule): ScheduleStatus {
  if (!s.is_active) return 'inactive'
  const now = Date.now()
  const start = new Date(s.starts_at).getTime()
  const end = s.ends_at ? new Date(s.ends_at).getTime() : null
  if (start > now) return 'upcoming'
  if (end != null && end < now) return 'ended'
  return 'active'
}

function statusBadge(status: ScheduleStatus): string {
  switch (status) {
    case 'active':
      return 'bg-green-100 text-green-800'
    case 'upcoming':
      return 'bg-blue-100 text-blue-800'
    case 'ended':
      return 'bg-gray-100 text-gray-600'
    case 'inactive':
      return 'bg-red-100 text-red-700'
  }
}

function toDatetimeLocal(iso: string | null): string {
  if (!iso) return ''
  const d = new Date(iso)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

function parseDatetimeLocal(value: string): Date | null {
  const trimmed = value.trim()
  if (!trimmed) return null
  const [datePart, timePart] = trimmed.split('T')
  if (!datePart || !timePart) return null
  const [year, month, day] = datePart.split('-').map(Number)
  const [hour, minute] = timePart.split(':').map(Number)
  if ([year, month, day, hour, minute].some((n) => Number.isNaN(n))) return null
  const parsed = new Date(year, month - 1, day, hour, minute, 0, 0)
  return Number.isNaN(parsed.getTime()) ? null : parsed
}

function newScheduleForm() {
  return {
    label: '',
    scheduleType: 'discount' as FareScheduleType,
    base: '40',
    perKm: '0',
    minimum: '40',
    startsAt: toDatetimeLocal(new Date().toISOString()),
    indefinite: true,
    endsAt: '',
  }
}

export function FarePage() {
  const [defaultFare, setDefaultFare] = useState<FareConfig | null>(null)
  const [effective, setEffective] = useState<EffectiveFare | null>(null)
  const [initializing, setInitializing] = useState(false)
  const [schedules, setSchedules] = useState<FareSchedule[]>([])
  const [base, setBase] = useState('')
  const [perKm, setPerKm] = useState('')
  const [minimum, setMinimum] = useState('')
  const [form, setForm] = useState(newScheduleForm)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [scheduleError, setScheduleError] = useState<string | null>(null)
  const [scheduleMessage, setScheduleMessage] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [scheduleSaving, setScheduleSaving] = useState(false)

  const refresh = useCallback(async () => {
    const [def, eff, list] = await Promise.all([
      fetchActiveFare(),
      fetchEffectiveFare(),
      listFareSchedules(),
    ])
    setDefaultFare(def)
    setEffective(eff)
    setSchedules(list)
    if (def) {
      setBase(String(def.base_fare))
      setPerKm(String(def.per_km_rate))
      setMinimum(String(def.minimum_fare))
    } else {
      setBase(String(DEFAULT_FARE.baseFare))
      setPerKm(String(DEFAULT_FARE.perKmRate))
      setMinimum(String(DEFAULT_FARE.minimumFare))
    }
  }, [])

  useEffect(() => {
    refresh()
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load fare'))
      .finally(() => setLoading(false))
  }, [refresh])

  async function handleSaveDefault() {
    setSaving(true)
    setError(null)
    setMessage(null)
    try {
      const payload = {
        baseFare: Number(base),
        perKmRate: Number(perKm),
        minimumFare: Number(minimum),
      }
      if (defaultFare) {
        await updateActiveFare({ id: defaultFare.id, ...payload })
        setMessage('Default fare updated')
      } else {
        await initializeDefaultFare(payload)
        setMessage('Default fare created')
      }
      await refresh()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed')
    } finally {
      setSaving(false)
    }
  }

  async function handleInitializeDefault() {
    setInitializing(true)
    setError(null)
    setMessage(null)
    try {
      await initializeDefaultFare()
      setMessage('Default fare initialized at ₱40')
      await refresh()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Initialize failed')
    } finally {
      setInitializing(false)
    }
  }

  function startEdit(s: FareSchedule) {
    setEditingId(s.id)
    setForm({
      label: s.label,
      scheduleType: s.schedule_type,
      base: String(s.base_fare),
      perKm: String(s.per_km_rate),
      minimum: String(s.minimum_fare),
      startsAt: toDatetimeLocal(s.starts_at),
      indefinite: s.ends_at == null,
      endsAt: toDatetimeLocal(s.ends_at),
    })
    setScheduleMessage(null)
    setScheduleError(null)
  }

  function cancelEdit() {
    setEditingId(null)
    setForm(newScheduleForm())
  }

  async function handleSaveSchedule() {
    setScheduleError(null)
    setScheduleMessage(null)

    if (!form.label.trim()) {
      setScheduleError('Label is required')
      return
    }

    const startDate = parseDatetimeLocal(form.startsAt)
    if (!startDate) {
      setScheduleError('Start date and time are required')
      return
    }

    let endIso: string | null = null
    if (!form.indefinite) {
      if (!form.endsAt.trim()) {
        setScheduleError('End date and time are required unless the schedule is indefinite')
        return
      }
      const endDate = parseDatetimeLocal(form.endsAt)
      if (!endDate) {
        setScheduleError('End date and time are invalid')
        return
      }
      if (endDate.getTime() <= startDate.getTime()) {
        setScheduleError('End must be after start')
        return
      }
      endIso = endDate.toISOString()
    }

    setScheduleSaving(true)
    try {
      const payload = {
        label: form.label.trim(),
        scheduleType: form.scheduleType,
        baseFare: Number(form.base),
        perKmRate: Number(form.perKm),
        minimumFare: Number(form.minimum),
        startsAt: startDate.toISOString(),
        endsAt: endIso,
      }
      if (editingId) {
        await updateFareSchedule(editingId, { ...payload, isActive: true })
        setScheduleMessage('Schedule updated')
      } else {
        await createFareSchedule(payload)
        setScheduleMessage('Schedule created')
      }
      cancelEdit()
      await refresh()
    } catch (e) {
      setScheduleError(supabaseErrorMessage(e, 'Schedule save failed'))
    } finally {
      setScheduleSaving(false)
    }
  }

  async function handleDeactivate(id: string) {
    setScheduleError(null)
    try {
      await deactivateFareSchedule(id)
      setScheduleMessage('Schedule deactivated')
      if (editingId === id) cancelEdit()
      await refresh()
    } catch (e) {
      setScheduleError(supabaseErrorMessage(e, 'Deactivate failed'))
    }
  }

  if (loading) return <LoadingState />

  return (
    <div className="space-y-6">
      {!defaultFare ? (
        <div className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">
          No active fare in the database yet. Showing ₱40 fallback. Initialize below to persist
          the default fare for rider and driver apps.
        </div>
      ) : null}

      <PanelCard title="Effective fare (now)" index={0}>
        {effective ? (
          <div className="flex flex-wrap items-start gap-4">
            <div>
              <p className="text-3xl font-semibold text-black/87">
                {formatPeso(effective.base_fare)}
                <span className="ml-2 text-base font-normal text-black/45">
                  base · min {formatPeso(effective.minimum_fare)}
                  {effective.per_km_rate > 0 ? ` · +${formatPeso(effective.per_km_rate)}/km` : ''}
                </span>
              </p>
              <p className="mt-2 text-sm text-black/55">
                {effective.fare_source === 'schedule' ? (
                  <>
                    From schedule{' '}
                    <strong>{effective.schedule_label || 'Unnamed'}</strong> — reverts to default
                    when the window ends.
                  </>
                ) : defaultFare ? (
                  <>Using default fare from fare_config.</>
                ) : (
                  <>Using ₱40 fallback until fare_config is initialized.</>
                )}
              </p>
            </div>
            <span
              className={`rounded-full px-3 py-1 text-xs font-medium capitalize ${
                effective.fare_source === 'schedule'
                  ? 'bg-amber-100 text-amber-800'
                  : 'bg-green-100 text-green-800'
              }`}
            >
              {effective.fare_source}
            </span>
          </div>
        ) : null}
      </PanelCard>

      <PanelCard title="Default fare (₱40 baseline)" index={1}>
        <p className="mb-6 text-sm text-black/55">
          Used when no scheduled override is active. Rider and driver apps read the resolved fare
          via <code className="rounded bg-admin-bg px-1">effective_fare_config</code>.
        </p>
        <div className="grid max-w-md gap-4">
          <label className="block">
            <span className="text-sm font-medium">Base fare (₱)</span>
            <input type="number" value={base} onChange={(e) => setBase(e.target.value)} className={inputCls} />
          </label>
          <label className="block">
            <span className="text-sm font-medium">Per km rate (₱)</span>
            <input type="number" value={perKm} onChange={(e) => setPerKm(e.target.value)} className={inputCls} />
          </label>
          <label className="block">
            <span className="text-sm font-medium">Minimum fare (₱)</span>
            <input
              type="number"
              value={minimum}
              onChange={(e) => setMinimum(e.target.value)}
              className={inputCls}
            />
          </label>
          <div className="flex flex-wrap gap-2">
            {!defaultFare ? (
              <PrimaryButton disabled={initializing} onClick={() => void handleInitializeDefault()}>
                {initializing ? 'Initializing…' : 'Initialize default fare (₱40)'}
              </PrimaryButton>
            ) : null}
            <PrimaryButton disabled={saving} onClick={() => void handleSaveDefault()}>
              {saving ? 'Saving…' : defaultFare ? 'Save default fare' : 'Save as new default fare'}
            </PrimaryButton>
          </div>
        </div>
        {message ? <p className="mt-4 text-sm text-green-700">{message}</p> : null}
        {error ? <p className="mt-4 text-sm text-red-700">{error}</p> : null}
      </PanelCard>

      <PanelCard title="Scheduled fare changes" index={2}>
        <p className="mb-4 text-sm text-black/55">
          Promotions (discount) or temporary/permanent overrides starting on a specific date. Leave
          end blank for indefinite; after a deadline the system automatically uses the default
          fare again.
        </p>

        {schedules.length === 0 ? (
          <p className="mb-4 text-sm text-black/45">No scheduled changes yet.</p>
        ) : (
          <div className="mb-6 overflow-x-auto">
            <table className="w-full min-w-[640px] text-left text-sm">
              <thead>
                <tr className="border-b border-admin-border text-black/45">
                  <th className="pb-3 pr-4 font-medium">Label</th>
                  <th className="pb-3 pr-4 font-medium">Type</th>
                  <th className="pb-3 pr-4 font-medium">Fare</th>
                  <th className="pb-3 pr-4 font-medium">Window</th>
                  <th className="pb-3 pr-4 font-medium">Status</th>
                  <th className="pb-3 font-medium">Actions</th>
                </tr>
              </thead>
              <tbody>
                {schedules.map((s) => {
                  const st = scheduleStatus(s)
                  return (
                    <tr key={s.id} className="border-b border-admin-border/70">
                      <td className="py-3 pr-4 font-medium">{s.label || '—'}</td>
                      <td className="py-3 pr-4 capitalize">{s.schedule_type}</td>
                      <td className="py-3 pr-4">
                        {formatPeso(s.base_fare)}
                        {s.per_km_rate > 0 ? ` +${formatPeso(s.per_km_rate)}/km` : ''}
                      </td>
                      <td className="py-3 pr-4 text-xs text-black/55">
                        <div>{formatDateTime(s.starts_at)}</div>
                        <div>{s.ends_at ? `→ ${formatDateTime(s.ends_at)}` : '→ indefinite'}</div>
                      </td>
                      <td className="py-3 pr-4">
                        <span
                          className={`rounded-full px-2 py-0.5 text-xs font-medium capitalize ${statusBadge(st)}`}
                        >
                          {st}
                        </span>
                      </td>
                      <td className="py-3">
                        <div className="flex gap-2">
                          <GhostButton onClick={() => startEdit(s)}>Edit</GhostButton>
                          {s.is_active ? (
                            <GhostButton onClick={() => void handleDeactivate(s.id)}>
                              Deactivate
                            </GhostButton>
                          ) : null}
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}

        <div className="rounded-xl border border-admin-border bg-admin-bg/40 p-4">
          <h4 className="mb-3 text-sm font-semibold text-black/80">
            {editingId ? 'Edit schedule' : 'New schedule'}
          </h4>
          <div className="grid max-w-2xl gap-4 sm:grid-cols-2">
            <label className="block sm:col-span-2">
              <span className="text-sm font-medium">Label</span>
              <input
                type="text"
                value={form.label}
                onChange={(e) => setForm((f) => ({ ...f, label: e.target.value }))}
                placeholder="e.g. Holiday promo"
                className={inputCls}
              />
            </label>
            <label className="block">
              <span className="text-sm font-medium">Type</span>
              <select
                value={form.scheduleType}
                onChange={(e) =>
                  setForm((f) => ({ ...f, scheduleType: e.target.value as FareScheduleType }))
                }
                className={inputCls}
              >
                <option value="discount">Discount / promotion</option>
                <option value="override">Override / increase</option>
              </select>
            </label>
            <label className="block">
              <span className="text-sm font-medium">Starts</span>
              <input
                type="datetime-local"
                value={form.startsAt}
                onChange={(e) => setForm((f) => ({ ...f, startsAt: e.target.value }))}
                className={inputCls}
              />
            </label>
            <label className="block">
              <span className="text-sm font-medium">Base fare (₱)</span>
              <input
                type="number"
                value={form.base}
                onChange={(e) => setForm((f) => ({ ...f, base: e.target.value }))}
                className={inputCls}
              />
            </label>
            <label className="block">
              <span className="text-sm font-medium">Per km (₱)</span>
              <input
                type="number"
                value={form.perKm}
                onChange={(e) => setForm((f) => ({ ...f, perKm: e.target.value }))}
                className={inputCls}
              />
            </label>
            <label className="block">
              <span className="text-sm font-medium">Minimum fare (₱)</span>
              <input
                type="number"
                value={form.minimum}
                onChange={(e) => setForm((f) => ({ ...f, minimum: e.target.value }))}
                className={inputCls}
              />
            </label>
            <div className="block sm:col-span-2">
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={form.indefinite}
                  onChange={(e) => setForm((f) => ({ ...f, indefinite: e.target.checked }))}
                />
                Indefinite (no end date)
              </label>
              {!form.indefinite ? (
                <label className="mt-3 block">
                  <span className="text-sm font-medium">Ends</span>
                  <input
                    type="datetime-local"
                    value={form.endsAt}
                    onChange={(e) => setForm((f) => ({ ...f, endsAt: e.target.value }))}
                    className={inputCls}
                  />
                </label>
              ) : null}
            </div>
          </div>
          <div className="mt-4 flex flex-wrap gap-2">
            <PrimaryButton disabled={scheduleSaving} onClick={() => void handleSaveSchedule()}>
              {scheduleSaving ? 'Saving…' : editingId ? 'Update schedule' : 'Add schedule'}
            </PrimaryButton>
            {editingId ? <GhostButton onClick={cancelEdit}>Cancel</GhostButton> : null}
          </div>
          {scheduleMessage ? (
            <p className="mt-4 text-sm text-green-700">{scheduleMessage}</p>
          ) : null}
          {scheduleError ? <p className="mt-4 text-sm text-red-700">{scheduleError}</p> : null}
        </div>
      </PanelCard>
    </div>
  )
}
