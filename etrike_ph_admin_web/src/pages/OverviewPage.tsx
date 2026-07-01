import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  Bar,
  BarChart,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { fetchFleetOverview } from '../services/admin'
import type { FleetOverview } from '../types'
import { formatPeso } from '../lib/format'
import { ErrorState, LoadingState, PanelCard, StatCard } from '../components/ui/AdminUi'

const PIE_COLORS = ['#2e7d32', '#94a3b8', '#f59e0b', '#ef4444']

export function OverviewPage() {
  const [data, setData] = useState<FleetOverview | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchFleetOverview()
      .then(setData)
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load overview'))
      .finally(() => setLoading(false))
  }, [])

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />
  if (!data) return null

  const pieData = [
    { name: 'On duty', value: data.driverStatus.onDuty },
    { name: 'Off duty', value: data.driverStatus.offDuty },
    { name: 'On leave', value: data.driverStatus.onLeave },
    { name: 'Pending', value: data.driverStatus.pending },
  ].filter((d) => d.value > 0)

  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard label="Active drivers" value={String(data.activeDrivers)} />
        <StatCard label="Pending approval" value={String(data.pendingApproval)} />
        <StatCard label="Trips today" value={String(data.tripsToday)} hint={`Yesterday: ${data.tripsYesterday}`} />
        <StatCard label="Fares today" value={formatPeso(data.faresToday)} hint={`Avg ${formatPeso(data.avgFareToday)}`} />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <PanelCard title="Trips — last 7 days">
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={data.tripsLast7Days}>
                <XAxis dataKey="label" tick={{ fontSize: 12 }} />
                <YAxis allowDecimals={false} tick={{ fontSize: 12 }} />
                <Tooltip />
                <Bar dataKey="count" fill="#2e7d32" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </PanelCard>

        <PanelCard title="Driver status">
          <div className="flex h-64 items-center gap-4">
            <ResponsiveContainer width="50%" height="100%">
              <PieChart>
                <Pie data={pieData} dataKey="value" nameKey="name" innerRadius={50} outerRadius={80}>
                  {pieData.map((_, i) => (
                    <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
            <ul className="space-y-2 text-sm">
              {pieData.map((d, i) => (
                <li key={d.name} className="flex items-center gap-2">
                  <span
                    className="h-2.5 w-2.5 rounded-full"
                    style={{ background: PIE_COLORS[i % PIE_COLORS.length] }}
                  />
                  {d.name}: {d.value}
                </li>
              ))}
            </ul>
          </div>
        </PanelCard>
      </div>

      {data.flaggedItems.length > 0 ? (
        <PanelCard title="Flagged items">
          <ul className="space-y-3">
            {data.flaggedItems.map((item, i) => (
              <li
                key={i}
                className="rounded-xl border border-admin-border bg-admin-bg px-4 py-3"
                style={{ borderLeftWidth: 4, borderLeftColor: item.borderColor }}
              >
                <p className="font-medium">{item.title}</p>
                <p className="text-sm text-black/55">{item.subtitle}</p>
                {item.tab ? (
                  <Link to={`/${item.tab}`} className="mt-2 inline-block text-sm text-admin-accent">
                    View →
                  </Link>
                ) : null}
                {item.driverId ? (
                  <Link
                    to={`/drivers/${item.driverId}`}
                    className="mt-2 inline-block text-sm text-admin-accent"
                  >
                    Open driver →
                  </Link>
                ) : null}
              </li>
            ))}
          </ul>
        </PanelCard>
      ) : null}

      {data.topDriversThisWeek.length > 0 ? (
        <PanelCard title="Top drivers this week">
          <ul className="divide-y divide-admin-border">
            {data.topDriversThisWeek.map((d) => (
              <li key={d.id} className="flex items-center justify-between py-3">
                <Link to={`/drivers/${d.id}`} className="font-medium text-admin-accent hover:underline">
                  {d.name}
                </Link>
                <span className="text-sm text-black/55">{d.trips} trips</span>
              </li>
            ))}
          </ul>
        </PanelCard>
      ) : null}
    </div>
  )
}
