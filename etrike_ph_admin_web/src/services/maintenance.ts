import { supabase } from '../lib/supabase'
import { throwSupabaseError } from '../lib/supabaseError'
import { logAudit } from './audit'
import type {
  AppMaintenanceRow,
  AppMaintenanceStatus,
  ScheduleMaintenanceInput,
} from '../types/maintenance'

function mapRow(row: Record<string, unknown>): AppMaintenanceRow {
  return {
    id: String(row.id),
    status: row.status as AppMaintenanceRow['status'],
    title: String(row.title ?? ''),
    message: String(row.message ?? ''),
    starts_at: String(row.starts_at ?? ''),
    ends_at: String(row.ends_at ?? ''),
    block_apps: Boolean(row.block_apps ?? true),
    notify_users: Boolean(row.notify_users ?? true),
    ended_early_at: row.ended_early_at != null ? String(row.ended_early_at) : null,
    created_by: row.created_by != null ? String(row.created_by) : null,
    updated_by: row.updated_by != null ? String(row.updated_by) : null,
    created_at: String(row.created_at ?? ''),
    updated_at: String(row.updated_at ?? ''),
  }
}

export async function fetchAppMaintenanceStatus(): Promise<AppMaintenanceStatus> {
  const { data, error } = await supabase.rpc('get_app_maintenance_status')
  if (error) throwSupabaseError(error, 'Failed to load maintenance status')
  const payload = (data ?? { phase: 'inactive' }) as Record<string, unknown>
  return {
    phase: (payload.phase as AppMaintenanceStatus['phase']) ?? 'inactive',
    id: payload.id != null ? String(payload.id) : undefined,
    title: payload.title != null ? String(payload.title) : undefined,
    message: payload.message != null ? String(payload.message) : undefined,
    starts_at: payload.starts_at != null ? String(payload.starts_at) : undefined,
    ends_at: payload.ends_at != null ? String(payload.ends_at) : undefined,
    block_apps: payload.block_apps != null ? Boolean(payload.block_apps) : undefined,
    notify_users: payload.notify_users != null ? Boolean(payload.notify_users) : undefined,
  }
}

export async function listMaintenanceWindows(limit = 20): Promise<AppMaintenanceRow[]> {
  const { data, error } = await supabase
    .from('app_maintenance')
    .select('*')
    .order('starts_at', { ascending: false })
    .limit(limit)
  if (error) throwSupabaseError(error, 'Failed to load maintenance history')
  return (data ?? []).map((r) => mapRow(r as Record<string, unknown>))
}

export async function fetchOpenMaintenanceWindow(): Promise<AppMaintenanceRow | null> {
  const { data, error } = await supabase
    .from('app_maintenance')
    .select('*')
    .in('status', ['scheduled', 'active'])
    .is('ended_early_at', null)
    .gt('ends_at', new Date().toISOString())
    .order('starts_at', { ascending: false })
    .limit(1)
    .maybeSingle()
  if (error) throwSupabaseError(error, 'Failed to load maintenance window')
  return data ? mapRow(data as Record<string, unknown>) : null
}

/** Re-authenticate operator before destructive maintenance actions. */
export async function confirmOperatorPassword(password: string): Promise<void> {
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user?.email) throw new Error('Not signed in')
  const { error } = await supabase.auth.signInWithPassword({
    email: user.email,
    password,
  })
  if (error) throw new Error('Password confirmation failed. Check your password and try again.')
}

export async function scheduleMaintenance(
  input: ScheduleMaintenanceInput,
): Promise<AppMaintenanceRow> {
  const { data, error } = await supabase.rpc('admin_schedule_maintenance', {
    p_title: input.title.trim(),
    p_message: input.message.trim(),
    p_starts_at: input.starts_at,
    p_ends_at: input.ends_at,
    p_block_apps: input.block_apps,
    p_notify_users: input.notify_users,
  })
  if (error) throwSupabaseError(error, 'Failed to schedule maintenance')
  const row = mapRow(data as Record<string, unknown>)
  await logAudit({
    action: 'maintenance.schedule',
    entityType: 'app_maintenance',
    entityId: row.id,
    summary: `Scheduled maintenance: ${row.title}`,
    metadata: { starts_at: row.starts_at, ends_at: row.ends_at, block_apps: row.block_apps },
  })
  return row
}

export async function extendMaintenance(
  id: string,
  newEndsAt: string,
): Promise<AppMaintenanceRow> {
  const { data, error } = await supabase.rpc('admin_extend_maintenance', {
    p_id: id,
    p_new_ends_at: newEndsAt,
  })
  if (error) throwSupabaseError(error, 'Failed to extend maintenance')
  const row = mapRow(data as Record<string, unknown>)
  await logAudit({
    action: 'maintenance.extend',
    entityType: 'app_maintenance',
    entityId: id,
    summary: `Extended maintenance until ${row.ends_at}`,
  })
  return row
}

export async function endMaintenanceNow(id: string): Promise<AppMaintenanceRow> {
  const { data, error } = await supabase.rpc('admin_end_maintenance_now', { p_id: id })
  if (error) throwSupabaseError(error, 'Failed to end maintenance')
  const row = mapRow(data as Record<string, unknown>)
  await logAudit({
    action: 'maintenance.end_now',
    entityType: 'app_maintenance',
    entityId: id,
    summary: 'Ended maintenance early',
  })
  return row
}

export async function cancelMaintenance(id: string): Promise<AppMaintenanceRow> {
  const { data, error } = await supabase.rpc('admin_cancel_maintenance', { p_id: id })
  if (error) throwSupabaseError(error, 'Failed to cancel maintenance')
  const row = mapRow(data as Record<string, unknown>)
  await logAudit({
    action: 'maintenance.cancel',
    entityType: 'app_maintenance',
    entityId: id,
    summary: 'Cancelled scheduled maintenance',
  })
  return row
}
