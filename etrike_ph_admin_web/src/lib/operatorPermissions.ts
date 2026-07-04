import type { OperatorApprovalStatus, OperatorRole } from '../types'

export type OperatorModule = 'drivers' | 'fleet' | 'hr' | 'payroll' | 'fare' | 'platform'

const APPROVED_ROLES: OperatorRole[] = [
  'super_admin',
  'admin',
  'viewer',
  'hr',
  'dispatcher',
]

function isApproved(
  role: OperatorRole | null,
  approvalStatus: OperatorApprovalStatus | 'none',
): role is OperatorRole {
  return approvalStatus === 'approved' && role != null && APPROVED_ROLES.includes(role)
}

/** Full admin operators (maintenance, team, delete, fare). */
export function operatorIsAdmin(
  role: OperatorRole | null,
  approvalStatus: OperatorApprovalStatus | 'none',
): boolean {
  return isApproved(role, approvalStatus) && (role === 'admin' || role === 'super_admin')
}

export function operatorIsSuperAdmin(
  role: OperatorRole | null,
  approvalStatus: OperatorApprovalStatus | 'none',
): boolean {
  return isApproved(role, approvalStatus) && role === 'super_admin'
}

export function operatorIsViewer(
  role: OperatorRole | null,
  approvalStatus: OperatorApprovalStatus | 'none',
): boolean {
  return isApproved(role, approvalStatus) && role === 'viewer'
}

export function operatorIsHr(
  role: OperatorRole | null,
  approvalStatus: OperatorApprovalStatus | 'none',
): boolean {
  return isApproved(role, approvalStatus) && role === 'hr'
}

export function operatorIsDispatcher(
  role: OperatorRole | null,
  approvalStatus: OperatorApprovalStatus | 'none',
): boolean {
  return isApproved(role, approvalStatus) && role === 'dispatcher'
}

/** @deprecated Use module-specific checks. True for admin/super_admin only. */
export function operatorCanWrite(
  role: OperatorRole | null,
  approvalStatus: OperatorApprovalStatus | 'none',
): boolean {
  return operatorIsAdmin(role, approvalStatus)
}

export function operatorCanWriteModule(
  module: OperatorModule,
  role: OperatorRole | null,
  approvalStatus: OperatorApprovalStatus | 'none',
): boolean {
  if (!isApproved(role, approvalStatus)) return false
  if (role === 'admin' || role === 'super_admin') return true
  if (role === 'viewer') return false
  if (role === 'dispatcher') {
    return module === 'drivers' || module === 'fleet'
  }
  if (role === 'hr') {
    return module === 'hr' || module === 'payroll'
  }
  return false
}

const ROUTE_ACCESS: Record<string, OperatorRole[] | 'all'> = {
  '/': 'all',
  '/audit': 'all',
  '/drivers': ['super_admin', 'admin', 'viewer', 'hr', 'dispatcher'],
  '/drivers/onboarding': ['super_admin', 'admin', 'viewer', 'hr', 'dispatcher'],
  '/training': ['super_admin', 'admin', 'viewer', 'hr', 'dispatcher'],
  '/fleet': ['super_admin', 'admin', 'viewer', 'dispatcher'],
  '/pending': ['super_admin', 'admin', 'viewer', 'dispatcher'],
  '/approved': ['super_admin', 'admin', 'viewer', 'dispatcher'],
  '/revoked': ['super_admin', 'admin', 'viewer', 'dispatcher'],
  '/attendance': ['super_admin', 'admin', 'viewer', 'hr', 'dispatcher'],
  '/leave': ['super_admin', 'admin', 'viewer', 'hr', 'dispatcher'],
  '/payroll': ['super_admin', 'admin', 'viewer', 'hr'],
  '/fare': ['super_admin', 'admin', 'viewer'],
  '/maintenance': ['super_admin', 'admin'],
  '/team': ['super_admin', 'admin'],
}

function routeKey(pathname: string): string {
  if (pathname === '/') return '/'
  if (pathname.startsWith('/drivers/onboarding')) return '/drivers/onboarding'
  if (pathname.startsWith('/fleet/')) return '/fleet'
  if (pathname.startsWith('/drivers/')) return '/drivers'
  for (const key of Object.keys(ROUTE_ACCESS)) {
    if (key !== '/' && pathname === key) return key
  }
  return pathname
}

export function operatorCanAccessRoute(
  pathname: string,
  role: OperatorRole | null,
  approvalStatus: OperatorApprovalStatus | 'none',
): boolean {
  if (!isApproved(role, approvalStatus)) return false
  const key = routeKey(pathname)
  const allowed = ROUTE_ACCESS[key]
  if (allowed === 'all') return true
  if (!allowed) return key === '/' || key === '/audit'
  return allowed.includes(role)
}

export type NavRoute = {
  to: string
  label: string
  end?: boolean
}

/** Sidebar routes for an approved operator role (icons assigned in layout). */
export function operatorNavRoutes(
  role: OperatorRole | null,
  approvalStatus: OperatorApprovalStatus | 'none',
): NavRoute[] {
  if (!isApproved(role, approvalStatus)) return [{ to: '/', label: 'Overview', end: true }]

  const items: NavRoute[] = [{ to: '/', label: 'Overview', end: true }]

  const drivers: NavRoute[] = [
    { to: '/drivers', label: 'Drivers' },
    { to: '/drivers/onboarding', label: 'Onboarding' },
  ]
  const fleetOps: NavRoute[] = [
    { to: '/fleet', label: 'Fleet' },
    { to: '/training', label: 'Training' },
    { to: '/pending', label: 'Pending' },
    { to: '/approved', label: 'Approved' },
    { to: '/revoked', label: 'Revoked' },
  ]
  const hrOps: NavRoute[] = [
    { to: '/attendance', label: 'Attendance' },
    { to: '/leave', label: 'Leave' },
    { to: '/payroll', label: 'Payroll' },
  ]
  const finance: NavRoute[] = [{ to: '/fare', label: 'Fare' }]
  const tail: NavRoute[] = [{ to: '/audit', label: 'Audit logs' }]

  switch (role) {
    case 'hr':
      items.push(...drivers, ...hrOps, ...tail)
      break
    case 'dispatcher':
      items.push(...drivers, ...fleetOps, { to: '/attendance', label: 'Attendance' }, { to: '/leave', label: 'Leave' }, ...tail)
      break
    case 'viewer':
      items.push(...drivers, ...fleetOps, ...hrOps, ...finance, ...tail)
      break
    case 'admin':
    case 'super_admin':
      items.push(...drivers, ...fleetOps, ...hrOps, ...finance, ...tail)
      items.push({ to: '/maintenance', label: 'Maintenance' }, { to: '/team', label: 'Team' })
      break
    default:
      break
  }

  return items
}

export function operatorRoleLabel(role: OperatorRole | null): string {
  if (!role) return 'Operator'
  return role.replace('_', ' ')
}

export function operatorAccessBannerMessage(role: OperatorRole | null): string | null {
  switch (role) {
    case 'viewer':
      return 'Viewer — read-only. You can browse operational data but cannot approve drivers, edit payroll, change fares, or modify fleet records.'
    case 'hr':
      return 'HR — you can manage attendance, leave, and payroll. Driver approval, fleet assignment, and fare settings are read-only or hidden.'
    case 'dispatcher':
      return 'Dispatcher — you can manage drivers, onboarding, training, and fleet. Payroll, fare settings, team, and maintenance are not available.'
    default:
      return null
  }
}
