import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import type { DriverTrainingRow, TrainingMode } from '../../types/training'
import {
  ensureDriverTraining,
  fetchDriverTraining,
  markOnsiteTrainingComplete,
  setDriverTrainingMode,
} from '../../services/training'
import {
  TRAINING_MODE_LABELS,
  TRAINING_STATUS_LABELS,
  trainingStatusClass,
} from '../../lib/trainingConstants'
import { formatDateTime } from '../../lib/format'
import { PanelCard, PrimaryButton } from '../ui/adminPageUi'
import { adminInputCls } from '../ui/AdminUi'

type Props = {
  driverId: string
  driverName?: string
  readOnly?: boolean
}

export function DriverTrainingPanel({ driverId, driverName, readOnly = false }: Props) {
  const [training, setTraining] = useState<DriverTrainingRow | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notes, setNotes] = useState('')

  const load = useCallback(() => {
    setLoading(true)
    fetchDriverTraining(driverId)
      .then(async (row) => {
        if (!row) {
          return ensureDriverTraining(driverId)
        }
        return row
      })
      .then(setTraining)
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load training'))
      .finally(() => setLoading(false))
  }, [driverId])

  useEffect(() => {
    load()
  }, [load])

  async function handleModeChange(mode: TrainingMode) {
    setBusy(true)
    setError(null)
    try {
      const row = await setDriverTrainingMode(driverId, mode)
      setTraining(row)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Update failed')
    } finally {
      setBusy(false)
    }
  }

  async function handleMarkOnsiteComplete() {
    setBusy(true)
    setError(null)
    try {
      const row = await markOnsiteTrainingComplete(driverId, notes)
      setTraining(row)
      setNotes('')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not mark complete')
    } finally {
      setBusy(false)
    }
  }

  return (
    <PanelCard title="Rider protocol training">
      {loading ? (
        <p className="text-sm text-black/45">Loading training record…</p>
      ) : training ? (
        <div className="space-y-4">
          {driverName ? (
            <p className="text-sm text-black/55">
              Training record for <strong>{driverName}</strong>. Drivers cannot go Online until
              status is <strong>Completed</strong>.
            </p>
          ) : null}
          <div className="flex flex-wrap items-center gap-2">
            <span
              className={`rounded-full px-2.5 py-0.5 text-xs font-semibold ${trainingStatusClass(training.status)}`}
            >
              {TRAINING_STATUS_LABELS[training.status]}
            </span>
            <span className="rounded-full bg-admin-bg px-2.5 py-0.5 text-xs text-black/55">
              {TRAINING_MODE_LABELS[training.mode]}
            </span>
            {training.quiz_score != null ? (
              <span className="text-xs text-black/45">Quiz: {training.quiz_score}%</span>
            ) : null}
          </div>
          {training.completed_at ? (
            <p className="text-xs text-black/45">
              Completed {formatDateTime(training.completed_at)}
            </p>
          ) : null}
          <label className="block max-w-xs">
            <span className="text-sm font-medium text-black/70">Training mode</span>
            <select
              className={`${adminInputCls} mt-1`}
              value={training.mode}
              disabled={readOnly || busy || training.status === 'completed'}
              onChange={(e) => void handleModeChange(e.target.value as TrainingMode)}
            >
              <option value="online">Online (app module + quiz)</option>
              <option value="onsite">Onsite (manual attendance)</option>
            </select>
          </label>
          {training.mode === 'onsite' && training.status !== 'completed' && !readOnly ? (
            <div className="rounded-xl border border-admin-border bg-admin-bg/40 p-4">
              <p className="text-sm text-black/55">
                After the driver attends the onsite session, mark completion below.
              </p>
              <label className="mt-3 block">
                <span className="text-sm font-medium text-black/70">Session notes (optional)</span>
                <textarea
                  className={`${adminInputCls} mt-1 min-h-[72px]`}
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Date, trainer name, topics covered…"
                />
              </label>
              <PrimaryButton disabled={busy} onClick={() => void handleMarkOnsiteComplete()}>
                Mark onsite training complete
              </PrimaryButton>
            </div>
          ) : null}
          {training.status === 'completed' && training.admin_notes ? (
            <p className="text-sm text-black/55">Notes: {training.admin_notes}</p>
          ) : null}
        </div>
      ) : null}
      {error ? <p className="mt-2 text-sm text-red-700">{error}</p> : null}
      <div className="mt-4">
        <Link to="/training" className="text-sm font-medium text-admin-accent hover:underline">
          View all training records →
        </Link>
      </div>
    </PanelCard>
  )
}

export function DriverTrainingPanelCompact({ driverId }: { driverId: string }) {
  return <DriverTrainingPanel driverId={driverId} />
}
