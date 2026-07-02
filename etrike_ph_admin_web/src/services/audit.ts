import { supabase } from '../lib/supabase'
import { supabaseErrorMessage } from '../lib/supabaseError'
import { auditActorRole, type AuditActorRole } from '../lib/auditActorRole'
import { endOfDayIso, matchesAuditSearch } from '../lib/auditSearch'
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

  let actorRole: AuditActorRole = 'operator'
  const { data: op } = await supabase
    .from('operators')
    .select('role')
    .eq('id', user.id)
    .maybeSingle()
  if (op?.role) actorRole = auditActorRole(op.role as string)

  const { error } = await supabase.from('audit_logs').insert({
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

  if (error) {
    console.warn('Audit log insert failed:', supabaseErrorMessage(error, error.message))
  }
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
  if (error) throw new Error(supabaseErrorMessage(error, 'Failed to load audit logs'))

  let rows = (data ?? []) as AuditLogRow[]
  if (filters.search?.trim()) {
    rows = rows.filter((r) => matchesAuditSearch(r, filters.search!))
  }
  return rows
}

export async function fetchAuditLogsForDriver(
  driverId: string,
  limit = 25,
): Promise<AuditLogRow[]> {
  const [asEntity, asActor] = await Promise.all([
    supabase
      .from('audit_logs')
      .select('*')
      .eq('entity_type', 'drivers')
      .eq('entity_id', driverId)
      .order('created_at', { ascending: false })
      .limit(limit),
    supabase
      .from('audit_logs')
      .select('*')
      .eq('actor_id', driverId)
      .order('created_at', { ascending: false })
      .limit(limit),
  ])

  const error = asEntity.error ?? asActor.error
  if (error) {
    console.warn('Driver audit logs:', supabaseErrorMessage(error, error.message))
    return []
  }

  const merged = new Map<string, AuditLogRow>()
  for (const row of [...(asEntity.data ?? []), ...(asActor.data ?? [])] as AuditLogRow[]) {
    merged.set(row.id, row)
  }

  return [...merged.values()]
    .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
    .slice(0, limit)
}
