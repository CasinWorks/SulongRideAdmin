export type AuditActorRole =
  | 'operator'
  | 'driver'
  | 'rider'
  | 'super_admin'
  | 'admin'
  | 'viewer'
  | 'hr'
  | 'dispatcher'

const KNOWN_ROLES: AuditActorRole[] = [
  'super_admin',
  'admin',
  'viewer',
  'hr',
  'dispatcher',
  'driver',
  'rider',
]

/** Map operators.role to audit_logs.actor_role (DB check constraint). */
export function auditActorRole(operatorRole: string | null | undefined): AuditActorRole {
  if (operatorRole && (KNOWN_ROLES as string[]).includes(operatorRole)) {
    return operatorRole as AuditActorRole
  }
  return 'operator'
}
