import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { ChevronRight } from 'lucide-react'
import { fetchRosterForDate, fetchShiftCountsForMonth } from '../services/roster'
import { rosterSummaryCounts, rosterStatusColor } from '../lib/rosterLogic'
import type { DayRosterSummary, DriverRosterEntry } from '../types/roster'
import { formatDateTime } from '../lib/format'
import { AdminMonthCalendar } from '../components/roster/AdminMonthCalendar'
import { OnlineDot, RosterStatusChip, RosterStatusLegend } from '../components/roster/RosterStatusChip'
import { ErrorState, LoadingState, PanelCard } from '../components/ui/adminPageUi'

export function AttendancePage() {
  const [focusedMonth, setFocusedMonth] = useState(() => new Date())
  const [selectedDay, setSelectedDay] = useState(() => new Date())
  const [shiftCounts, setShiftCounts] = useState<Record<string, number>>({})
  const [roster, setRoster] = useState<DayRosterSummary | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [counts, dayRoster] = await Promise.all([
        fetchShiftCountsForMonth(focusedMonth),
        fetchRosterForDate(selectedDay),
      ])
      setShiftCounts(counts)
      setRoster(dayRoster)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load roster')
    } finally {
      setLoading(false)
    }
  }, [focusedMonth, selectedDay])

  useEffect(() => {
    void load()
  }, [load])

  useEffect(() => {
    fetchShiftCountsForMonth(focusedMonth)
      .then(setShiftCounts)
      .catch(() => {})
  }, [focusedMonth])

  if (loading && !roster) return <LoadingState />
  if (error && !roster) return <ErrorState message={error} />

  const summary = roster ? rosterSummaryCounts(roster) : null
  const selectedLabel = selectedDay.toLocaleDateString(undefined, {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  })

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-black/87">Attendance & roster</h1>
        <p className="mt-1 text-sm text-black/55">{selectedLabel}</p>
      </div>

      <div className="grid gap-6 xl:grid-cols-[minmax(300px,360px)_1fr]">
        <AdminMonthCalendar
          focusedMonth={focusedMonth}
          selectedDay={selectedDay}
          shiftCounts={shiftCounts}
          onDaySelected={setSelectedDay}
          onMonthChanged={setFocusedMonth}
        />

        <div className="space-y-4">
          {summary ? (
            <div className="flex flex-wrap gap-3">
              <SummaryPill label="On shift" value={summary.onShift} color="#059669" />
              <SummaryPill label="Online" value={summary.online} color="#2563EB" />
              <SummaryPill label="On leave" value={summary.onLeave} color="#D97706" />
              <SummaryPill label="Off duty" value={summary.offDuty} color="#9CA3AF" />
            </div>
          ) : null}

          <PanelCard title={roster ? `Roster (${roster.entries.length} drivers)` : 'Roster'}>
            {loading ? (
              <p className="py-8 text-center text-sm text-black/45">Refreshing…</p>
            ) : roster && roster.entries.length === 0 ? (
              <p className="py-8 text-center text-sm text-black/45">No drivers in the system yet.</p>
            ) : (
              <ul className="space-y-2">
                {roster?.entries.map((entry) => (
                  <RosterRow key={entry.driverId} entry={entry} />
                ))}
              </ul>
            )}
          </PanelCard>
        </div>
      </div>

      <RosterStatusLegend />
    </div>
  )
}

function SummaryPill({
  label,
  value,
  color,
}: {
  label: string
  value: number
  color: string
}) {
  return (
    <div
      className="rounded-xl border bg-white px-4 py-3"
      style={{ borderColor: `${color}40` }}
    >
      <span className="text-xl font-bold" style={{ color }}>
        {value}
      </span>
      <span className="ml-2 text-sm text-black/55">{label}</span>
    </div>
  )
}

function RosterRow({ entry }: { entry: DriverRosterEntry }) {
  const borderColor = rosterStatusColor(entry.status)
  return (
    <li>
      <Link
        to={`/drivers/${entry.driverId}`}
        className="flex items-start gap-3 rounded-xl border-l-4 bg-admin-bg/50 p-3 transition hover:bg-admin-bg"
        style={{ borderLeftColor: borderColor }}
      >
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-admin-accent/15 text-sm font-semibold text-admin-accent">
          {entry.fullName.charAt(0).toUpperCase()}
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <p className="font-semibold text-black/87">{entry.fullName}</p>
            <RosterStatusChip status={entry.status} compact />
          </div>
          <p className="mt-1 text-xs text-black/55">
            {entry.station} · {entry.shiftSchedule}
          </p>
          <p className="text-xs text-black/45">
            {entry.employmentType}
            {entry.plate ? ` · ${entry.plate}` : ''}
          </p>
          {entry.clockIn ? (
            <p className="mt-1 text-xs text-black/45">
              Clock: {formatDateTime(entry.clockIn)}
              {entry.clockOut ? ` – ${formatDateTime(entry.clockOut)}` : ' – active'}
            </p>
          ) : null}
          {entry.leaveType ? (
            <p className="text-xs font-medium" style={{ color: borderColor }}>
              Approved leave: {entry.leaveType}
            </p>
          ) : null}
          <div className="mt-1">
            <OnlineDot online={entry.isOnline} />
          </div>
        </div>
        <ChevronRight size={18} className="shrink-0 text-black/30" />
      </Link>
    </li>
  )
}
