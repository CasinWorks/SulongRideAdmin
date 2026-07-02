export type AuditActorRole = 'operator' | 'driver' | 'rider' | 'super_admin' | 'admin' | 'viewer'

/** Map operators.role to audit_logs.actor_role (DB check constraint). */
export function auditActorRole(operatorRole: string | null | undefined): AuditActorRole {
  if (operatorRole === 'super_admin' || operatorRole === 'admin' || operatorRole === 'viewer') {
    return operatorRole
  }
  if (operatorRole === 'driver' || operatorRole === 'rider') return operatorRole
  return 'operator'
}
