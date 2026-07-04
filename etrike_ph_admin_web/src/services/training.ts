import { supabase } from '../lib/supabase'
import type { DriverTrainingRow, DriverTrainingWithProfile, TrainingMode } from '../types/training'

function mapTraining(row: Record<string, unknown>): DriverTrainingRow {
  return {
    driver_id: String(row.driver_id),
    status: (row.status as DriverTrainingRow['status']) ?? 'not_started',
    mode: (row.mode as DriverTrainingRow['mode']) ?? 'online',
    started_at: (row.started_at as string) ?? null,
    completed_at: (row.completed_at as string) ?? null,
    completed_by: row.completed_by != null ? String(row.completed_by) : null,
    quiz_passed_at: (row.quiz_passed_at as string) ?? null,
    quiz_score: row.quiz_score != null ? Number(row.quiz_score) : null,
    admin_notes: (row.admin_notes as string) ?? null,
    created_at: String(row.created_at ?? ''),
    updated_at: String(row.updated_at ?? ''),
  }
}

export async function fetchDriverTraining(driverId: string): Promise<DriverTrainingRow | null> {
  const { data, error } = await supabase
    .from('driver_training')
    .select('*')
    .eq('driver_id', driverId)
    .maybeSingle()
  if (error) throw error
  return data ? mapTraining(data) : null
}

export async function ensureDriverTraining(
  driverId: string,
  mode: TrainingMode = 'online',
): Promise<DriverTrainingRow> {
  const existing = await fetchDriverTraining(driverId)
  if (existing) return existing
  const now = new Date().toISOString()
  const { data, error } = await supabase
    .from('driver_training')
    .insert({
      driver_id: driverId,
      status: 'not_started',
      mode,
      created_at: now,
      updated_at: now,
    })
    .select('*')
    .single()
  if (error) throw error
  return mapTraining(data)
}

export async function setDriverTrainingMode(
  driverId: string,
  mode: TrainingMode,
): Promise<DriverTrainingRow> {
  const existing = await ensureDriverTraining(driverId, mode)
  if (existing.status === 'completed') {
    throw new Error('Training is already completed. Cannot change mode.')
  }
  const now = new Date().toISOString()
  const payload: Record<string, unknown> = {
    mode,
    updated_at: now,
  }
  if (mode === 'onsite') {
    payload.status = 'not_started'
    payload.quiz_score = null
    payload.quiz_passed_at = null
    payload.completed_at = null
  }
  const { data, error } = await supabase
    .from('driver_training')
    .update(payload)
    .eq('driver_id', driverId)
    .select('*')
    .single()
  if (error) throw error
  return mapTraining(data)
}

export async function markOnsiteTrainingComplete(
  driverId: string,
  notes?: string,
): Promise<DriverTrainingRow> {
  await ensureDriverTraining(driverId, 'onsite')
  const now = new Date().toISOString()
  const { data: session } = await supabase.auth.getSession()
  const { data, error } = await supabase
    .from('driver_training')
    .update({
      status: 'completed',
      mode: 'onsite',
      completed_at: now,
      completed_by: session.session?.user.id ?? null,
      admin_notes: notes?.trim() || null,
      updated_at: now,
    })
    .eq('driver_id', driverId)
    .select('*')
    .single()
  if (error) throw error

  await supabase.from('onboarding_timeline').insert({
    driver_id: driverId,
    actor_id: session.session?.user.id,
    action: 'training_completed',
    summary: 'Onsite rider protocol training marked complete',
  })

  return mapTraining(data)
}

export async function listDriverTraining(
  statusFilter?: DriverTrainingRow['status'],
): Promise<DriverTrainingWithProfile[]> {
  let query = supabase.from('driver_training').select('*').order('updated_at', { ascending: false })
  if (statusFilter) query = query.eq('status', statusFilter)
  const { data: trainingRows, error } = await query
  if (error) throw error
  if (!trainingRows?.length) return []

  const driverIds = trainingRows.map((r) => r.driver_id as string)
  const { data: drivers, error: driversError } = await supabase
    .from('drivers')
    .select('id, full_name, email, approval_status')
    .in('id', driverIds)
  if (driversError) throw driversError

  const driverMap = new Map(
    (drivers ?? []).map((d) => [String(d.id), d as Record<string, unknown>]),
  )

  return trainingRows.map((row) => {
    const t = mapTraining(row as Record<string, unknown>)
    const d = driverMap.get(t.driver_id)
    return {
      ...t,
      full_name: String(d?.full_name ?? 'Driver'),
      email: String(d?.email ?? ''),
      approval_status: String(d?.approval_status ?? 'pending'),
    }
  })
}

export async function listDriversMissingTraining(): Promise<DriverTrainingWithProfile[]> {
  const { data: drivers, error } = await supabase
    .from('drivers')
    .select('id, full_name, email, approval_status')
    .eq('approval_status', 'approved')
  if (error) throw error

  const approved = drivers ?? []
  if (!approved.length) return []

  const ids = approved.map((d) => String(d.id))
  const { data: trainingRows, error: tErr } = await supabase
    .from('driver_training')
    .select('*')
    .in('driver_id', ids)
  if (tErr) throw tErr

  const trainingMap = new Map(
    (trainingRows ?? []).map((r) => [String(r.driver_id), mapTraining(r as Record<string, unknown>)]),
  )

  return approved
    .filter((d) => trainingMap.get(String(d.id))?.status !== 'completed')
    .map((d) => {
      const t =
        trainingMap.get(String(d.id)) ??
        ({
          driver_id: String(d.id),
          status: 'not_started',
          mode: 'online',
          started_at: null,
          completed_at: null,
          completed_by: null,
          quiz_passed_at: null,
          quiz_score: null,
          admin_notes: null,
          created_at: '',
          updated_at: '',
        } satisfies DriverTrainingRow)
      return {
        ...t,
        full_name: String(d.full_name ?? 'Driver'),
        email: String(d.email ?? ''),
        approval_status: String(d.approval_status ?? 'approved'),
      }
    })
}
