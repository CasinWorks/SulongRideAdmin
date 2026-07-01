import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { fetchWeeklyTripsByDriver, listDrivers } from '../services/admin'
import type { DriverRow } from '../types'
import { driverDisplayName, formatDate } from '../lib/format'
import { ErrorState, LoadingState, PanelCard, StatusPill } from '../components/ui/AdminUi'

export function DriversPage() {
  const [drivers, setDrivers] = useState<DriverRow[]>([])
  const [weekly, setWeekly] = useState<Record<string, number>>({})
  const [query, setQuery] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    Promise.all([listDrivers(), fetchWeeklyTripsByDriver()])
      .then(([d, w]) => {
        setDrivers(d)
        setWeekly(w)
      })
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load drivers'))
      .finally(() => setLoading(false))
  }, [])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return drivers
    return drivers.filter(
      (d) =>
        d.full_name.toLowerCase().includes(q) ||
        d.email.toLowerCase().includes(q) ||
        (d.trike_plate_number?.toLowerCase().includes(q) ?? false),
    )
  }, [drivers, query])

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  return (
    <PanelCard
      title="Drivers directory"
      action={
        <input
          type="search"
          placeholder="Search name, email, plate…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          className="w-full rounded-xl border border-admin-border px-3 py-2 text-sm outline-none focus:border-admin-accent sm:w-64"
        />
      }
    >
      <div className="overflow-x-auto">
        <table className="w-full min-w-[640px] text-left text-sm">
          <thead>
            <tr className="border-b border-admin-border text-black/45">
              <th className="pb-3 pr-4 font-medium">Driver</th>
              <th className="pb-3 pr-4 font-medium">Status</th>
              <th className="pb-3 pr-4 font-medium">Plate</th>
              <th className="pb-3 pr-4 font-medium">Trips (7d)</th>
              <th className="pb-3 font-medium">Joined</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((d) => (
              <tr key={d.id} className="border-b border-admin-border/70">
                <td className="py-3 pr-4">
                  <Link to={`/drivers/${d.id}`} className="font-medium text-admin-accent hover:underline">
                    {driverDisplayName(d)}
                  </Link>
                  <p className="text-xs text-black/45">{d.email}</p>
                </td>
                <td className="py-3 pr-4">
                  <StatusPill status={d.approval_status} />
                  {d.is_online ? (
                    <span className="ml-2 text-xs text-green-700">online</span>
                  ) : null}
                </td>
                <td className="py-3 pr-4">{d.trike_plate_number ?? '—'}</td>
                <td className="py-3 pr-4">{weekly[d.id] ?? 0}</td>
                <td className="py-3">{formatDate(d.created_at)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {filtered.length === 0 ? (
          <p className="py-8 text-center text-black/45">No drivers match your search.</p>
        ) : null}
      </div>
    </PanelCard>
  )
}
