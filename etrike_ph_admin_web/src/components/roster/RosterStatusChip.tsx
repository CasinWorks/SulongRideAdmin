import type { DriverDayStatus } from '../../types/roster'
import { rosterStatusColor, rosterStatusLabel } from '../../lib/rosterLogic'

type Props = {
  status: DriverDayStatus
  compact?: boolean
}

const COMPACT_LABEL: Partial<Record<DriverDayStatus, string>> = {
  on_leave_vl: 'VL',
  on_leave_sl: 'SL',
  on_shift: 'On shift',
  online: 'Online',
  off_duty: 'Off duty',
  pending: 'Pending',
  revoked: 'Revoked',
}

export function RosterStatusChip({ status, compact = false }: Props) {
  const color = rosterStatusColor(status)
  const label = compact ? (COMPACT_LABEL[status] ?? rosterStatusLabel(status)) : rosterStatusLabel(status)
  return (
    <span
      className="inline-flex rounded-full border px-2 py-0.5 text-[11px] font-semibold"
      style={{
        color,
        borderColor: `${color}59`,
        backgroundColor: `${color}1f`,
      }}
    >
      {label}
    </span>
  )
}

export function OnlineDot({ online }: { online: boolean }) {
  return (
    <span className="inline-flex items-center gap-1.5 text-xs">
      <span
        className={`inline-block h-2 w-2 rounded-full ${online ? 'bg-admin-accent' : 'bg-black/20'}`}
      />
      <span className={online ? 'font-medium text-admin-accent' : 'text-black/45'}>
        {online ? 'Online' : 'Offline'}
      </span>
    </span>
  )
}

export function RosterStatusLegend() {
  const statuses: DriverDayStatus[] = [
    'on_shift',
    'online',
    'on_leave_vl',
    'on_leave_sl',
    'off_duty',
  ]
  return (
    <div className="flex flex-wrap gap-3">
      {statuses.map((s) => (
        <RosterStatusChip key={s} status={s} compact />
      ))}
    </div>
  )
}
