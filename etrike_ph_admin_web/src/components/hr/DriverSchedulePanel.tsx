import { useCallback, useEffect, useState } from 'react'
import { fetchDriverSchedule } from '../../services/roster'
import { dayKey, parseDayKey } from '../../lib/rosterLogic'
import type { DriverScheduleDay } from '../../types/roster'
import { formatDateTime } from '../../lib/format'
import { AdminMonthCalendar } from '../roster/AdminMonthCalendar'
import { RosterStatusChip } from '../roster/RosterStatusChip'
import { PanelCard } from '../ui/adminPageUi'

type Props = {
  driverId: string
}

export function DriverSchedulePanel({ driverId }: Props) {
  const [focusedMonth, setFocusedMonth] = useState(() => new Date())
  const [selectedDay, setSelectedDay] = useState(() => new Date())
  const [days, setDays] = useState<DriverScheduleDay[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(() => {
    setLoading(true)
    fetchDriverSchedule(driverId, focusedMonth)
      .then(setDays)
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load schedule'))
      .finally(() => setLoading(false))
  }, [driverId, focusedMonth])

  useEffect(() => {
    load()
  }, [load])

  const selectedKey = dayKey(selectedDay)
  const selected = days.find((d) => d.date === selectedKey)

  return (
    <PanelCard title="Schedule & attendance">
      {error ? <p className="mb-3 text-sm text-red-700">{error}</p> : null}
      {loading ? (
        <p className="py-8 text-center text-sm text-black/45">Loading calendar…</p>
      ) : (
        <div className="grid gap-6 lg:grid-cols-[minmax(280px,360px)_1fr]">
          <AdminMonthCalendar
            focusedMonth={focusedMonth}
            selectedDay={selectedDay}
            onDaySelected={setSelectedDay}
            onMonthChanged={(m) => {
              setFocusedMonth(m)
            }}
          />
          <div>
            {selected ? (
              <DayDetail day={selected} />
            ) : (
              <p className="text-sm text-black/45">No data for this day.</p>
            )}
          </div>
        </div>
      )}
    </PanelCard>
  )
}

function DayDetail({ day }: { day: DriverScheduleDay }) {
  const date = parseDayKey(day.date)
  return (
    <div className="rounded-xl border border-admin-border bg-admin-bg/40 p-4">
      <div className="flex items-center justify-between gap-2">
        <p className="font-semibold text-black/87">
          {date.toLocaleDateString(undefined, {
            weekday: 'short',
            month: 'short',
            day: 'numeric',
            year: 'numeric',
          })}
        </p>
        <RosterStatusChip status={day.status} compact />
      </div>

      {day.leaveType ? (
        <p className="mt-2 text-sm text-black/65">Approved leave: {day.leaveType}</p>
      ) : day.status === 'off_duty' && day.attendanceBlocks.length === 0 ? (
        <p className="mt-2 text-sm text-black/45">Not a scheduled work day</p>
      ) : null}

      {day.attendanceBlocks.length > 0 ? (
        <div className="mt-3">
          <p className="text-sm font-medium text-black/70">Time in / out</p>
          <ul className="mt-1 space-y-1 text-sm text-black/55">
            {day.attendanceBlocks.map((b, i) => (
              <li key={i}>
                {formatDateTime(b.clockIn)} →{' '}
                {b.clockOut ? formatDateTime(b.clockOut) : 'active'}
              </li>
            ))}
          </ul>
        </div>
      ) : day.leaveType == null ? (
        <p className="mt-2 text-sm text-black/45">No attendance recorded.</p>
      ) : null}
    </div>
  )
}
