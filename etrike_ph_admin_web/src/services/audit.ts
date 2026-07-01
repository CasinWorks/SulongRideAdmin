import { supabase } from '../lib/supabase'
import type { AuditLogRow } from '../types'

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

  try {
    await supabase.from('audit_logs').insert({
      actor_id: user.id,
      actor_role: 'operator',
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

export async function fetchAuditLogs(limit = 100): Promise<AuditLogRow[]> {
  const { data, error } = await supabase
    .from('audit_logs')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit)

  if (error) throw error
  return (data ?? []) as AuditLogRow[]
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
