import type { AuditLogRow } from '../types'

export function endOfDayIso(dateStr: string): string {
  const d = new Date(`${dateStr}T23:59:59.999`)
  return d.toISOString()
}

export function matchesAuditSearch(row: AuditLogRow, search: string): boolean {
  const q = search.trim().toLowerCase()
  if (!q) return true
  const haystack = [
    row.summary,
    row.action,
    row.actor_email ?? '',
    row.actor_name ?? '',
    row.entity_id ?? '',
  ]
    .join(' ')
    .toLowerCase()
  return haystack.includes(q)
}
