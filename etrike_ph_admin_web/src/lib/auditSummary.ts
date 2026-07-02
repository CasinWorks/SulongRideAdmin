import { formatPeso } from './format'

/** Strip characters that must not appear in audit log summary text. */
export function sanitizeAuditText(value: string, maxLen = 120): string {
  return value
    .replace(/[\0-\x1f'"\\;]/g, '')
    .trim()
    .slice(0, maxLen)
}

export function auditSummaryUpdatedFareSchedule(label: string): string {
  const safe = sanitizeAuditText(label)
  return safe.length > 0 ? `Updated scheduled fare (${safe})` : 'Updated scheduled fare'
}

export function auditSummaryFareRates(
  prefix: string,
  rates: { base: number; perKm: number; minimum: number },
): string {
  const parts = [
    prefix,
    `base ${formatPeso(rates.base)}`,
    `per km ${formatPeso(rates.perKm)}`,
    `min ${formatPeso(rates.minimum)}`,
  ]
  return parts.join(' — ')
}

export function auditSummaryOperatorAction(
  action: string,
  identifier: string,
  detail: string,
): string {
  const safeId = sanitizeAuditText(identifier)
  const safeDetail = sanitizeAuditText(detail)
  return [action, safeId, safeDetail].filter(Boolean).join(' — ')
}

export function auditSummaryDriverApproval(status: string): string {
  return `Driver approval set to ${sanitizeAuditText(status, 32)}`
}

export function auditSummaryLeaveReview(status: string): string {
  return `Leave request ${sanitizeAuditText(status, 32)}`
}

export function auditSummaryTeamApproval(
  targetEmail: string,
  status: 'approved' | 'revoked' | 'pending',
): string {
  const email = sanitizeAuditText(targetEmail)
  if (status === 'approved') return `Team member approved — ${email}`
  if (status === 'revoked') return `Team member revoked — ${email}`
  return `Team member marked pending — ${email}`
}

export function auditSummaryTeamInvite(
  action: 'send' | 'revoke' | 'accept',
  email: string,
  role?: string,
): string {
  const safeEmail = sanitizeAuditText(email)
  if (action === 'send') {
    const safeRole = role ? sanitizeAuditText(role, 32) : ''
    return safeRole
      ? `Team invite sent — ${safeEmail} (${safeRole})`
      : `Team invite sent — ${safeEmail}`
  }
  if (action === 'revoke') return `Team invite revoked — ${safeEmail}`
  return `Team invite accepted — ${safeEmail}`
}
