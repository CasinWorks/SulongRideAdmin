import { ChevronLeft, ChevronRight } from 'lucide-react'
import { dayKey, parseDayKey } from '../../lib/rosterLogic'

type Props = {
  focusedMonth: Date
  selectedDay: Date
  shiftCounts?: Record<string, number>
  onDaySelected: (day: Date) => void
  onMonthChanged: (month: Date) => void
}

const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

function monthLabel(d: Date): string {
  return d.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })
}

function isSameDay(a: Date, b: Date): boolean {
  return dayKey(a) === dayKey(b)
}

function buildMonthGrid(focusedMonth: Date): (Date | null)[][] {
  const first = new Date(focusedMonth.getFullYear(), focusedMonth.getMonth(), 1)
  const last = new Date(focusedMonth.getFullYear(), focusedMonth.getMonth() + 1, 0)
  const startOffset = (first.getDay() + 6) % 7
  const cells: (Date | null)[] = []

  for (let i = 0; i < startOffset; i++) cells.push(null)
  for (let day = 1; day <= last.getDate(); day++) {
    cells.push(new Date(focusedMonth.getFullYear(), focusedMonth.getMonth(), day))
  }
  while (cells.length % 7 !== 0) cells.push(null)

  const weeks: (Date | null)[][] = []
  for (let i = 0; i < cells.length; i += 7) {
    weeks.push(cells.slice(i, i + 7))
  }
  return weeks
}

export function AdminMonthCalendar({
  focusedMonth,
  selectedDay,
  shiftCounts = {},
  onDaySelected,
  onMonthChanged,
}: Props) {
  const today = new Date()
  const weeks = buildMonthGrid(focusedMonth)

  function changeMonth(delta: number) {
    const next = new Date(focusedMonth.getFullYear(), focusedMonth.getMonth() + delta, 1)
    onMonthChanged(next)
  }

  return (
    <div className="rounded-2xl border border-admin-border bg-white p-4 shadow-sm">
      <div className="mb-4 flex items-center justify-between">
        <button
          type="button"
          aria-label="Previous month"
          className="rounded-lg p-2 text-black/55 hover:bg-admin-bg"
          onClick={() => changeMonth(-1)}
        >
          <ChevronLeft size={18} />
        </button>
        <p className="text-sm font-semibold text-black/87">{monthLabel(focusedMonth)}</p>
        <button
          type="button"
          aria-label="Next month"
          className="rounded-lg p-2 text-black/55 hover:bg-admin-bg"
          onClick={() => changeMonth(1)}
        >
          <ChevronRight size={18} />
        </button>
      </div>

      <div className="grid grid-cols-7 gap-1 text-center text-[11px] font-medium text-black/45">
        {WEEKDAYS.map((d) => (
          <div key={d} className="py-1">
            {d}
          </div>
        ))}
      </div>

      <div className="mt-1 space-y-1">
        {weeks.map((week, wi) => (
          <div key={wi} className="grid grid-cols-7 gap-1">
            {week.map((day, di) => {
              if (!day) return <div key={di} className="aspect-square" />
              const key = dayKey(day)
              const count = shiftCounts[key]
              const selected = isSameDay(day, selectedDay)
              const isToday = isSameDay(day, today)
              return (
                <button
                  key={key}
                  type="button"
                  onClick={() => onDaySelected(parseDayKey(key))}
                  className={`relative flex aspect-square flex-col items-center justify-center rounded-full text-sm transition ${
                    selected
                      ? 'bg-admin-accent font-semibold text-white'
                      : isToday
                        ? 'bg-admin-accent/15 font-semibold text-admin-accent'
                        : 'text-black/75 hover:bg-admin-bg'
                  }`}
                >
                  {day.getDate()}
                  {count != null && count > 0 ? (
                    <span
                      className={`absolute bottom-0.5 rounded px-1 text-[9px] font-bold leading-none ${
                        selected ? 'bg-white/25 text-white' : 'bg-admin-accent/15 text-admin-accent'
                      }`}
                    >
                      {count}
                    </span>
                  ) : null}
                </button>
              )
            })}
          </div>
        ))}
      </div>
    </div>
  )
}
