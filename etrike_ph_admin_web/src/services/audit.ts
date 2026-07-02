import { supabase } from '../lib/supabase'
import type { AuditLogFilters, AuditLogRow } from '../types'

export async function logAudit(params: {
  action: string
  summary: string
  entityType?: string
  entityId?: string
  metadata?: Record<string, unknown>
}): Promise<void> {
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return

  let actorRole = 'operator'
  try {
    const { data: op } = await supabase
      .from('operators')
      .select('role')
      .eq('id', user.id)
      .maybeSingle()
    if (op?.role) actorRole = op.role as string
  } catch {
    /* optional */
  }

  try {
    await supabase.from('audit_logs').insert({
      actor_id: user.id,
      actor_role: actorRole,
      actor_email: user.email,
      action: params.action,
      entity_type: params.entityType ?? null,
      entity_id: params.entityId ?? null,
      summary: params.summary,
      metadata: params.metadata ?? {},
      app_source: 'admin',
    })
  } catch {
    // Never block primary action if audit fails.
  }
}

function endOfDayIso(dateStr: string): string {
  const d = new Date(`${dateStr}T23:59:59.999`)
  return d.toISOString()
}

function matchesSearch(row: AuditLogRow, search: string): boolean {
  const q = search.trim().toLowerCase()
  if (!q) return true
  const haystack = [
    row.summary,
    row.action,
    row.actor_email ?? '',
    row.entity_id ?? '',
  ]
    .join(' ')
    .toLowerCase()
  return haystack.includes(q)
}

export async function fetchAuditLogs(
  filtersOrLimit: AuditLogFilters | number = 100,
): Promise<AuditLogRow[]> {
  const filters: AuditLogFilters =
    typeof filtersOrLimit === 'number' ? { limit: filtersOrLimit } : filtersOrLimit
  const limit = filters.limit ?? 500

  let query = supabase
    .from('audit_logs')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit)

  if (filters.dateFrom) {
    query = query.gte('created_at', `${filters.dateFrom}T00:00:00.000Z`)
  }
  if (filters.dateTo) {
    query = query.lte('created_at', endOfDayIso(filters.dateTo))
  }
  if (filters.action) query = query.eq('action', filters.action)
  if (filters.appSource) query = query.eq('app_source', filters.appSource)
  if (filters.actorRole) query = query.eq('actor_role', filters.actorRole)

  const { data, error } = await query
  if (error) throw error

  let rows = (data ?? []) as AuditLogRow[]
  if (filters.search?.trim()) {
    rows = rows.filter((r) => matchesSearch(r, filters.search!))
  }
  return rows
}

export async function fetchAuditLogsForDriver(
  driverId: string,
  limit = 25,
): Promise<AuditLogRow[]> {
  const { data, error } = await supabase
    .from('audit_logs')
    .select('*')
    .or(
      `and(entity_type.eq.drivers,entity_id.eq.${driverId}),actor_id.eq.${driverId}`,
    )
    .order('created_at', { ascending: false })
    .limit(limit)

  if (error) return []
  return (data ?? []) as AuditLogRow[]
}
