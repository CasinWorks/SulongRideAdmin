import { useEffect, useState } from 'react'
import { fetchDriver } from '../../services/admin'
import { updateDriverShift } from '../../services/roster'
import type { DriverRow } from '../../types'
import {
  DEFAULT_STATION,
} from '../../lib/onboardingConstants'
import {
  PRESET_STATIONS,
  SHIFT_PRESETS,
  WEEKDAY_LABELS,
  employmentLabel,
  formatTime,
  shiftConfigFromDriver,
  shiftDisplayString,
  type ShiftConfig,
} from '../../lib/shiftConfig'
import { GhostButton, PanelCard, PrimaryButton, adminInputCls } from '../ui/adminPageUi'

type Props = {
  driverId: string
  driverName?: string
  readOnly?: boolean
  onChanged?: () => void
}

export function DriverShiftSetupPanel({
  driverId,
  driverName,
  readOnly = false,
  onChanged,
}: Props) {
  const [driver, setDriver] = useState<DriverRow | null>(null)
  const [draft, setDraft] = useState<ShiftConfig | null>(null)
  const [editing, setEditing] = useState(false)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [customStation, setCustomStation] = useState(false)

  function load() {
    setLoading(true)
    fetchDriver(driverId)
      .then((d) => {
        setDriver(d)
        if (d) setDraft(shiftConfigFromDriver(d))
      })
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load'))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [driverId])

  async function handleSave() {
    if (!draft) return
    if (draft.days.size === 0) {
      setError('Select at least one work day')
      return
    }
    setBusy(true)
    setError(null)
    try {
      await updateDriverShift(driverId, draft, driverName)
      setEditing(false)
      load()
      onChanged?.()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed')
    } finally {
      setBusy(false)
    }
  }

  function applyPreset(key: string) {
    const preset = SHIFT_PRESETS[key]
    if (!preset || !draft) return
    setDraft({
      ...draft,
      days: new Set(preset.days),
      startHour: preset.startHour,
      startMinute: preset.startMinute,
      endHour: preset.endHour,
      endMinute: preset.endMinute,
    })
  }

  if (loading) {
    return (
      <PanelCard title="Work schedule">
        <p className="py-6 text-center text-sm text-black/45">Loading schedule…</p>
      </PanelCard>
    )
  }

  if (!driver || !draft) {
    return (
      <PanelCard title="Work schedule">
        <p className="text-sm text-red-700">Driver not found</p>
      </PanelCard>
    )
  }

  const stationValue = PRESET_STATIONS.includes(draft.station as (typeof PRESET_STATIONS)[number])
    ? draft.station
    : '__other__'

  return (
    <PanelCard
      title="Work schedule"
      action={
        !readOnly && !editing ? (
          <GhostButton
            onClick={() => {
              setDraft(shiftConfigFromDriver(driver))
              setCustomStation(!PRESET_STATIONS.includes(driver.station as (typeof PRESET_STATIONS)[number]))
              setEditing(true)
            }}
          >
            Edit
          </GhostButton>
        ) : null
      }
    >
      {error ? <p className="mb-3 text-sm text-red-700">{error}</p> : null}

      {!editing ? (
        <dl className="space-y-2 text-sm">
          <Row label="Days" value={shiftDisplayString(draft).split(' · ')[0] ?? '—'} />
          <Row
            label="Hours"
            value={`${formatTime(draft.startHour, draft.startMinute)} – ${formatTime(draft.endHour, draft.endMinute)}`}
          />
          <Row label="Station" value={draft.station} />
          <Row label="Employment" value={employmentLabel(draft.employmentType)} />
          <p className="pt-2 text-xs text-black/45">{driver.shift_schedule}</p>
        </dl>
      ) : (
        <div className="space-y-4">
          <div>
            <p className="text-sm font-medium text-black/70">Quick presets</p>
            <div className="mt-2 flex flex-wrap gap-2">
              {Object.keys(SHIFT_PRESETS).map((key) => (
                <button
                  key={key}
                  type="button"
                  className="rounded-full border border-admin-border bg-admin-bg px-3 py-1 text-xs font-medium hover:border-admin-accent"
                  onClick={() => applyPreset(key)}
                >
                  {key}
                </button>
              ))}
            </div>
          </div>

          <div>
            <p className="text-sm font-medium text-black/70">Work days</p>
            <div className="mt-2 flex flex-wrap gap-2">
              {WEEKDAY_LABELS.map((label, i) => {
                const day = i + 1
                const selected = draft.days.has(day)
                return (
                  <button
                    key={day}
                    type="button"
                    className={`rounded-full border px-3 py-1 text-xs font-semibold ${
                      selected
                        ? 'border-admin-accent bg-admin-accent/15 text-admin-accent'
                        : 'border-admin-border bg-white text-black/55'
                    }`}
                    onClick={() => {
                      const next = new Set(draft.days)
                      if (selected) next.delete(day)
                      else next.add(day)
                      setDraft({ ...draft, days: next })
                    }}
                  >
                    {label}
                  </button>
                )
              })}
            </div>
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            <label className="block text-sm">
              <span className="font-medium text-black/70">Shift start</span>
              <input
                type="time"
                className={`${adminInputCls} mt-1`}
                value={`${String(draft.startHour).padStart(2, '0')}:${String(draft.startMinute).padStart(2, '0')}`}
                onChange={(e) => {
                  const [h, m] = e.target.value.split(':').map(Number)
                  setDraft({ ...draft, startHour: h, startMinute: m })
                }}
              />
            </label>
            <label className="block text-sm">
              <span className="font-medium text-black/70">Shift end</span>
              <input
                type="time"
                className={`${adminInputCls} mt-1`}
                value={`${String(draft.endHour).padStart(2, '0')}:${String(draft.endMinute).padStart(2, '0')}`}
                onChange={(e) => {
                  const [h, m] = e.target.value.split(':').map(Number)
                  setDraft({ ...draft, endHour: h, endMinute: m })
                }}
              />
            </label>
          </div>

          <label className="block text-sm">
            <span className="font-medium text-black/70">Station / depot</span>
            <select
              className={`${adminInputCls} mt-1`}
              value={stationValue}
              onChange={(e) => {
                const v = e.target.value
                if (v === '__other__') {
                  setCustomStation(true)
                  setDraft({ ...draft, station: '' })
                } else {
                  setCustomStation(false)
                  setDraft({ ...draft, station: v })
                }
              }}
            >
              {PRESET_STATIONS.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
              <option value="__other__">Other…</option>
            </select>
          </label>

          {customStation || stationValue === '__other__' ? (
            <label className="block text-sm">
              <span className="font-medium text-black/70">Custom station name</span>
              <input
                className={`${adminInputCls} mt-1`}
                value={draft.station}
                placeholder={DEFAULT_STATION}
                onChange={(e) => setDraft({ ...draft, station: e.target.value })}
              />
            </label>
          ) : null}

          <label className="block text-sm">
            <span className="font-medium text-black/70">Employment type</span>
            <select
              className={`${adminInputCls} mt-1`}
              value={draft.employmentType}
              onChange={(e) => setDraft({ ...draft, employmentType: e.target.value })}
            >
              <option value="contractual">Contractual</option>
              <option value="permanent">Permanent</option>
            </select>
          </label>

          <div className="flex flex-wrap gap-2 pt-2">
            <GhostButton
              disabled={busy}
              onClick={() => {
                setEditing(false)
                setDraft(shiftConfigFromDriver(driver))
                setError(null)
              }}
            >
              Cancel
            </GhostButton>
            <PrimaryButton disabled={busy} onClick={() => void handleSave()}>
              {busy ? 'Saving…' : 'Save schedule'}
            </PrimaryButton>
          </div>
        </div>
      )}
    </PanelCard>
  )
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex gap-4">
      <dt className="w-24 shrink-0 text-black/45">{label}</dt>
      <dd className="font-medium text-black/87">{value}</dd>
    </div>
  )
}
