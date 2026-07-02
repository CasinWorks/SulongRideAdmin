import { supabase } from '../lib/supabase'
import { throwSupabaseError } from '../lib/supabaseError'
import { logAudit } from './audit'
import type { OperatorInvitePreview, OperatorInviteRow, OperatorRole } from '../types'

function mapInvite(row: Record<string, unknown>): OperatorInviteRow {
  return {
    id: String(row.id),
    token: String(row.token),
    email: String(row.email),
    role: row.role as OperatorRole,
    status: row.status as OperatorInviteRow['status'],
    invited_by: row.invited_by != null ? String(row.invited_by) : null,
    created_at: String(row.created_at),
    expires_at: String(row.expires_at),
    accepted_at: row.accepted_at != null ? String(row.accepted_at) : null,
    accepted_by: row.accepted_by != null ? String(row.accepted_by) : null,
  }
}

export function operatorInviteUrl(token: string): string {
  return `${window.location.origin}/invite/${token}`
}

export async function listOperatorInvites(): Promise<OperatorInviteRow[]> {
  const { data, error } = await supabase
    .from('operator_invites')
    .select('*')
    .order('created_at', { ascending: false })

  if (error) throw error
  return (data ?? []).map((row) => mapInvite(row as Record<string, unknown>))
}

export async function createOperatorInvite(
  email: string,
  role: OperatorRole,
): Promise<OperatorInviteRow> {
  const normalized = email.trim().toLowerCase()
  const {
    data: { user },
  } = await supabase.auth.getUser()

  const { data, error } = await supabase
    .from('operator_invites')
    .insert({
      email: normalized,
      role,
      invited_by: user?.id ?? null,
    })
    .select('*')
    .single()

  if (error) throw error

  const invite = mapInvite(data as Record<string, unknown>)

  await logAudit({
    action: 'operator.invite.create',
    entityType: 'operator_invites',
    entityId: invite.id,
    summary: `Operator invite sent to ${normalized}`,
    metadata: { email: normalized, role, token: invite.token },
  })

  return invite
}

export async function revokeOperatorInvite(inviteId: string): Promise<void> {
  const { data: before, error: fetchError } = await supabase
    .from('operator_invites')
    .select('email, status')
    .eq('id', inviteId)
    .maybeSingle()

  if (fetchError) throw fetchError
  if (!before || before.status !== 'pending') {
    throw new Error('Only pending invites can be revoked')
  }

  const { error } = await supabase
    .from('operator_invites')
    .update({ status: 'revoked' })
    .eq('id', inviteId)
    .eq('status', 'pending')

  if (error) throw error

  await logAudit({
    action: 'operator.invite.revoke',
    entityType: 'operator_invites',
    entityId: inviteId,
    summary: `Operator invite revoked for ${String(before.email)}`,
    metadata: { email: before.email },
  })
}

export async function fetchOperatorInviteByToken(
  token: string,
): Promise<OperatorInvitePreview | null> {
  const { data, error } = await supabase.rpc('get_operator_invite_by_token', {
    p_token: token,
  })

  if (error) throwSupabaseError(error, 'Could not load invite')
  const row = Array.isArray(data) ? data[0] : data
  if (!row) return null

  return {
    email: String(row.email),
    role: row.role as OperatorRole,
    status: row.status as OperatorInvitePreview['status'],
    expires_at: String(row.expires_at),
    accepted_at: row.accepted_at != null ? String(row.accepted_at) : null,
  }
}

export async function claimOperatorInvite(token: string): Promise<void> {
  const { error } = await supabase.rpc('claim_operator_invite', { p_token: token })
  if (error) throw error

  await logAudit({
    action: 'operator.invite.claim',
    summary: 'Operator invite accepted',
    metadata: { token },
  })
}
