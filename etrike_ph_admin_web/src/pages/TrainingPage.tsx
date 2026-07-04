import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { listDriverTraining, listDriversMissingTraining } from '../services/training'
import type { DriverTrainingWithProfile } from '../types/training'
import {
  TRAINING_MODE_LABELS,
  TRAINING_STATUS_LABELS,
  trainingStatusClass,
} from '../lib/trainingConstants'
import { formatDateTime } from '../lib/format'
import { ErrorState, LoadingState, PanelCard, adminSearchInputCls } from '../components/ui/adminPageUi'

type Tab = 'all' | 'missing' | 'not_started' | 'in_progress' | 'completed'

export function TrainingPage() {
  const [tab, setTab] = useState<Tab>('missing')
  const [rows, setRows] = useState<DriverTrainingWithProfile[]>([])
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  function load() {
    setLoading(true)
    setError(null)
    const promise =
      tab === 'missing'
        ? listDriversMissingTraining()
        : listDriverTraining(tab === 'all' ? undefined : tab)
    promise
      .then(setRows)
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load'))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return rows
    return rows.filter(
      (r) =>
        r.full_name.toLowerCase().includes(q) ||
        r.email.toLowerCase().includes(q) ||
        r.driver_id.toLowerCase().includes(q),
    )
  }, [rows, query])

  const tabs: { id: Tab; label: string }[] = [
    { id: 'missing', label: 'Approved · not trained' },
    { id: 'not_started', label: 'Not started' },
    { id: 'in_progress', label: 'In progress' },
    { id: 'completed', label: 'Completed' },
    { id: 'all', label: 'All records' },
  ]

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold">Driver training</h2>
        <p className="mt-1 text-sm text-black/55">
          Rider protocol training — online module with quiz, or onsite sessions you mark complete.
          Drivers cannot go Online until training is completed.
        </p>
      </div>

      <div className="flex flex-wrap gap-2">
        {tabs.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => setTab(t.id)}
            className={`rounded-xl border px-3 py-2 text-sm font-medium ${
              tab === t.id
                ? 'border-admin-accent bg-admin-accent/10 text-black/87'
                : 'border-admin-border bg-white text-black/55 hover:bg-admin-bg'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      <PanelCard
        title={`${filtered.length} driver${filtered.length === 1 ? '' : 's'}`}
        action={
          <input
            type="search"
            placeholder="Search name or email…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className={adminSearchInputCls}
          />
        }
      >
        {filtered.length === 0 ? (
          <p className="py-8 text-center text-sm text-black/45">No matching training records.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-left text-sm">
              <thead>
                <tr className="border-b border-admin-border text-black/45">
                  <th className="pb-3 pr-4 font-medium">Driver</th>
                  <th className="pb-3 pr-4 font-medium">Approval</th>
                  <th className="pb-3 pr-4 font-medium">Training</th>
                  <th className="pb-3 pr-4 font-medium">Mode</th>
                  <th className="pb-3 pr-4 font-medium">Completed</th>
                  <th className="pb-3 font-medium" />
                </tr>
              </thead>
              <tbody>
                {filtered.map((r) => (
                  <tr key={r.driver_id} className="border-b border-admin-border/70">
                    <td className="py-3 pr-4">
                      <Link
                        to={`/drivers/${r.driver_id}`}
                        className="font-medium text-admin-accent hover:underline"
                      >
                        {r.full_name}
                      </Link>
                      <p className="text-xs text-black/45">{r.email}</p>
                    </td>
                    <td className="py-3 pr-4 capitalize">{r.approval_status}</td>
                    <td className="py-3 pr-4">
                      <span
                        className={`rounded-full px-2 py-0.5 text-xs font-semibold ${trainingStatusClass(r.status)}`}
                      >
                        {TRAINING_STATUS_LABELS[r.status]}
                      </span>
                      {r.quiz_score != null ? (
                        <span className="ml-2 text-xs text-black/45">{r.quiz_score}%</span>
                      ) : null}
                    </td>
                    <td className="py-3 pr-4">{TRAINING_MODE_LABELS[r.mode]}</td>
                    <td className="py-3 pr-4 text-black/55">
                      {r.completed_at ? formatDateTime(r.completed_at) : '—'}
                    </td>
                    <td className="py-3">
                      <Link
                        to={`/drivers/${r.driver_id}`}
                        className="text-xs font-medium text-admin-accent hover:underline"
                      >
                        Manage
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </PanelCard>
    </div>
  )
}
