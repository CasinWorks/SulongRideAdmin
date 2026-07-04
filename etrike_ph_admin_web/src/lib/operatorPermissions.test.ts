import { describe, expect, it } from 'vitest'
import {
  operatorCanAccessRoute,
  operatorCanWriteModule,
  operatorIsDispatcher,
  operatorIsHr,
  operatorNavRoutes,
  operatorRoleLabel,
} from './operatorPermissions'

const approved = 'approved' as const

describe('operatorPermissions', () => {
  it('labels hr and dispatcher roles', () => {
    expect(operatorRoleLabel('hr')).toBe('hr')
    expect(operatorRoleLabel('dispatcher')).toBe('dispatcher')
  })

  it('filters nav for hr vs dispatcher', () => {
    const hrNav = operatorNavRoutes('hr', approved).map((n) => n.to)
    const dispatchNav = operatorNavRoutes('dispatcher', approved).map((n) => n.to)

    expect(hrNav).toContain('/payroll')
    expect(hrNav).not.toContain('/fleet')
    expect(dispatchNav).toContain('/fleet')
    expect(dispatchNav).not.toContain('/payroll')
    expect(dispatchNav).not.toContain('/fare')
  })

  it('write modules by role', () => {
    expect(operatorCanWriteModule('payroll', 'hr', approved)).toBe(true)
    expect(operatorCanWriteModule('fleet', 'hr', approved)).toBe(false)
    expect(operatorCanWriteModule('drivers', 'dispatcher', approved)).toBe(true)
    expect(operatorCanWriteModule('payroll', 'dispatcher', approved)).toBe(false)
    expect(operatorCanWriteModule('fare', 'admin', approved)).toBe(true)
    expect(operatorCanWriteModule('drivers', 'viewer', approved)).toBe(false)
  })

  it('route access guards', () => {
    expect(operatorCanAccessRoute('/payroll', 'hr', approved)).toBe(true)
    expect(operatorCanAccessRoute('/fleet', 'hr', approved)).toBe(false)
    expect(operatorCanAccessRoute('/fleet', 'dispatcher', approved)).toBe(true)
    expect(operatorCanAccessRoute('/maintenance', 'admin', approved)).toBe(true)
    expect(operatorCanAccessRoute('/maintenance', 'dispatcher', approved)).toBe(false)
  })

  it('detects specialist roles', () => {
    expect(operatorIsHr('hr', approved)).toBe(true)
    expect(operatorIsDispatcher('dispatcher', approved)).toBe(true)
  })
})
