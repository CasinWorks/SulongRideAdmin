import { useEffect, useState } from 'react'
import { listAttendance } from '../services/admin'
import type { AttendanceRow } from '../types'
import { driverDisplayName, formatDateTime } from '../lib/format'
import { ErrorState, LoadingState, PanelCard } from '../components/ui/adminPageUi'

export function AttendancePage() {
  const [rows, setRows] = useState<AttendanceRow[]>([])
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    listAttendance(100)
      .then(setRows)
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load attendance'))
      .finally(() => setLoading(false))
  }, [])

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  const openShifts = rows.filter((r) => !r.clock_out).length

  return (
    <div className="space-y-4">
      <p className="text-sm text-black/55">
        <strong>{openShifts}</strong> drivers currently clocked in (open shifts).
      </p>
      <PanelCard title="Recent attendance">
        {rows.length === 0 ? (
          <p className="py-8 text-center text-black/45">
            No attendance records yet. Run fix_driver_shift.sql if the table is missing.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[560px] text-left text-sm">
              <thead>
                <tr className="border-b border-admin-border text-black/45">
                  <th className="pb-3 pr-4 font-medium">Driver</th>
                  <th className="pb-3 pr-4 font-medium">Clock in</th>
                  <th className="pb-3 font-medium">Clock out</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id} className="border-b border-admin-border/70">
                    <td className="py-3 pr-4">
                      {r.drivers ? driverDisplayName(r.drivers) : r.driver_id}
                    </td>
                    <td className="py-3 pr-4">{formatDateTime(r.clock_in)}</td>
                    <td className="py-3">
                      {r.clock_out ? (
                        formatDateTime(r.clock_out)
                      ) : (
                        <span className="font-medium text-green-700">On shift</span>
                      )}
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
