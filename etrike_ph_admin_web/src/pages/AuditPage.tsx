import { useEffect, useState } from 'react'
import { fetchAuditLogs } from '../services/audit'
import type { AuditLogRow } from '../types'
import { formatDateTime } from '../lib/format'
import { ErrorState, LoadingState, PanelCard } from '../components/ui/AdminUi'

export function AuditPage() {
  const [rows, setRows] = useState<AuditLogRow[]>([])
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchAuditLogs(150)
      .then(setRows)
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load audit logs'))
      .finally(() => setLoading(false))
  }, [])

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  return (
    <PanelCard title="Audit logs">
      <p className="mb-4 text-sm text-black/55">
        Cross-app actions from admin, driver, and rider clients.
      </p>
      {rows.length === 0 ? (
        <p className="py-8 text-center text-black/45">
          No logs yet. Run fix_audit_logs.sql if the table is missing.
        </p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-[720px] text-left text-sm">
            <thead>
              <tr className="border-b border-admin-border text-black/45">
                <th className="pb-3 pr-4 font-medium">When</th>
                <th className="pb-3 pr-4 font-medium">Action</th>
                <th className="pb-3 pr-4 font-medium">Summary</th>
                <th className="pb-3 pr-4 font-medium">Actor</th>
                <th className="pb-3 font-medium">App</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} className="border-b border-admin-border/70">
                  <td className="py-3 pr-4 whitespace-nowrap">{formatDateTime(r.created_at)}</td>
                  <td className="py-3 pr-4 font-mono text-xs">{r.action}</td>
                  <td className="py-3 pr-4">{r.summary}</td>
                  <td className="py-3 pr-4 text-black/55">{r.actor_email ?? '—'}</td>
                  <td className="py-3">{r.app_source ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </PanelCard>
  )
}
