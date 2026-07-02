import { useCallback, useEffect, useMemo, useState } from 'react'
import { fetchAuditLogs } from '../services/audit'
import type { AuditLogFilters, AuditLogRow } from '../types'
import { formatDateTime } from '../lib/format'
import { ErrorState, GhostButton, LoadingState, PanelCard } from '../components/ui/AdminUi'

const APP_SOURCES = ['admin', 'driver', 'rider'] as const
const ACTOR_ROLES = ['operator', 'driver', 'rider'] as const

function defaultDateFrom(): string {
  const d = new Date()
  d.setDate(d.getDate() - 30)
  return d.toISOString().slice(0, 10)
}

function defaultDateTo(): string {
  return new Date().toISOString().slice(0, 10)
}

const inputCls =
  'rounded-xl border border-admin-border px-3 py-2 text-sm outline-none focus:border-admin-accent'

function FilterChip({
  label,
  active,
  onClick,
}: {
  label: string
  active: boolean
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`rounded-full px-3 py-1 text-xs font-medium transition ${
        active
          ? 'bg-admin-accent text-white'
          : 'border border-admin-border bg-white text-black/60 hover:bg-admin-bg'
      }`}
    >
      {label}
    </button>
  )
}

export function AuditPage() {
  const [rows, setRows] = useState<AuditLogRow[]>([])
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  const [search, setSearch] = useState('')
  const [dateFrom, setDateFrom] = useState(defaultDateFrom)
  const [dateTo, setDateTo] = useState(defaultDateTo)
  const [action, setAction] = useState('')
  const [appSource, setAppSource] = useState('')
  const [actorRole, setActorRole] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const filters: AuditLogFilters = {
        dateFrom,
        dateTo,
        limit: 500,
      }
      if (action) filters.action = action
      if (appSource) filters.appSource = appSource
      if (actorRole) filters.actorRole = actorRole
      const data = await fetchAuditLogs(filters)
      setRows(data)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load audit logs')
    } finally {
      setLoading(false)
    }
  }, [dateFrom, dateTo, action, appSource, actorRole])

  useEffect(() => {
    void load()
  }, [load])

  const filteredRows = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return rows
    return rows.filter((r) => {
      const haystack = [r.summary, r.action, r.actor_email ?? '', r.entity_id ?? '']
        .join(' ')
        .toLowerCase()
      return haystack.includes(q)
    })
  }, [rows, search])

  const actionOptions = useMemo(() => {
    const set = new Set(rows.map((r) => r.action))
    return [...set].sort()
  }, [rows])

  function resetFilters() {
    setSearch('')
    setDateFrom(defaultDateFrom())
    setDateTo(defaultDateTo())
    setAction('')
    setAppSource('')
    setActorRole('')
  }

  return (
    <PanelCard
      title="Audit logs"
      action={
        <input
          type="search"
          placeholder="Search summary, action, email, entity…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className={`w-full sm:w-72 ${inputCls}`}
        />
      }
    >
      <p className="mb-4 text-sm text-black/55">
        Cross-app actions from admin, driver, and rider clients.
      </p>

      <div className="mb-5 flex flex-wrap items-end gap-3 rounded-xl border border-admin-border bg-admin-bg/50 p-4">
        <label className="block">
          <span className="text-xs font-medium text-black/50">From</span>
          <input
            type="date"
            value={dateFrom}
            onChange={(e) => setDateFrom(e.target.value)}
            className={`mt-1 block ${inputCls}`}
          />
        </label>
        <label className="block">
          <span className="text-xs font-medium text-black/50">To</span>
          <input
            type="date"
            value={dateTo}
            onChange={(e) => setDateTo(e.target.value)}
            className={`mt-1 block ${inputCls}`}
          />
        </label>
        <label className="block min-w-[140px]">
          <span className="text-xs font-medium text-black/50">Action</span>
          <select
            value={action}
            onChange={(e) => setAction(e.target.value)}
            className={`mt-1 block w-full ${inputCls}`}
          >
            <option value="">All actions</option>
            {actionOptions.map((a) => (
              <option key={a} value={a}>
                {a}
              </option>
            ))}
          </select>
        </label>
        <div className="flex flex-col gap-1.5">
          <span className="text-xs font-medium text-black/50">App</span>
          <div className="flex flex-wrap gap-1.5">
            <FilterChip label="All" active={!appSource} onClick={() => setAppSource('')} />
            {APP_SOURCES.map((s) => (
              <FilterChip
                key={s}
                label={s}
                active={appSource === s}
                onClick={() => setAppSource(appSource === s ? '' : s)}
              />
            ))}
          </div>
        </div>
        <div className="flex flex-col gap-1.5">
          <span className="text-xs font-medium text-black/50">Actor role</span>
          <div className="flex flex-wrap gap-1.5">
            <FilterChip label="All" active={!actorRole} onClick={() => setActorRole('')} />
            {ACTOR_ROLES.map((r) => (
              <FilterChip
                key={r}
                label={r}
                active={actorRole === r}
                onClick={() => setActorRole(actorRole === r ? '' : r)}
              />
            ))}
          </div>
        </div>
        <GhostButton onClick={() => void load()}>Apply</GhostButton>
        <GhostButton onClick={resetFilters}>Reset</GhostButton>
      </div>

      {loading ? <LoadingState label="Loading audit logs…" /> : null}
      {error ? <ErrorState message={error} /> : null}

      {!loading && !error ? (
        filteredRows.length === 0 ? (
          <p className="py-8 text-center text-black/45">
            No logs match your filters. Run fix_audit_logs.sql if the table is missing.
          </p>
        ) : (
          <>
            <p className="mb-3 text-xs text-black/45">{filteredRows.length} log(s)</p>
            <div className="overflow-x-auto">
              <table className="w-full min-w-[720px] text-left text-sm">
                <thead>
                  <tr className="border-b border-admin-border text-black/45">
                    <th className="pb-3 pr-4 font-medium">When</th>
                    <th className="pb-3 pr-4 font-medium">Action</th>
                    <th className="pb-3 pr-4 font-medium">Summary</th>
                    <th className="pb-3 pr-4 font-medium">Actor</th>
                    <th className="pb-3 pr-4 font-medium">Role</th>
                    <th className="pb-3 font-medium">App</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredRows.map((r) => (
                    <tr key={r.id} className="border-b border-admin-border/70">
                      <td className="py-3 pr-4 whitespace-nowrap">
                        {formatDateTime(r.created_at)}
                      </td>
                      <td className="py-3 pr-4 font-mono text-xs">{r.action}</td>
                      <td className="py-3 pr-4">{r.summary}</td>
                      <td className="py-3 pr-4 text-black/55">{r.actor_email ?? '—'}</td>
                      <td className="py-3 pr-4 capitalize text-black/45">
                        {r.actor_role ?? '—'}
                      </td>
                      <td className="py-3">{r.app_source ?? '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )
      ) : null}
    </PanelCard>
  )
}
