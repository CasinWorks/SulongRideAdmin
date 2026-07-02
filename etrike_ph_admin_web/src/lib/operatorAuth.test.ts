import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest'
import {
  dualRoleOperatorEmail,
  friendlyAuthError,
  isDualRoleOperatorEmail,
  isEmailAllowedForOperator,
  oauthRedirectUrl,
  operatorEmailDomain,
} from './operatorAuth'

describe('operatorEmailDomain', () => {
  beforeEach(() => {
    vi.stubEnv('VITE_OPERATOR_EMAIL_DOMAIN', 'casinworks.com')
  })

  afterEach(() => {
    vi.unstubAllEnvs()
  })

  it('reads configured domain', () => {
    expect(operatorEmailDomain()).toBe('casinworks.com')
  })
})

describe('isEmailAllowedForOperator', () => {
  beforeEach(() => {
    vi.stubEnv('VITE_OPERATOR_EMAIL_DOMAIN', 'casinworks.com')
  })

  afterEach(() => {
    vi.unstubAllEnvs()
  })

  it('allows matching domain emails', () => {
    expect(isEmailAllowedForOperator('ops@casinworks.com')).toBe(true)
  })

  it('rejects other domains', () => {
    expect(isEmailAllowedForOperator('ops@gmail.com')).toBe(false)
  })
})

describe('isDualRoleOperatorEmail', () => {
  it('matches the default dual-role email', () => {
    expect(isDualRoleOperatorEmail('christianjoshuacasin@gmail.com')).toBe(true)
    expect(isDualRoleOperatorEmail('ChristianJoshuaCasin@gmail.com')).toBe(true)
  })

  it('rejects other emails', () => {
    expect(isDualRoleOperatorEmail('other@gmail.com')).toBe(false)
    expect(isDualRoleOperatorEmail(undefined)).toBe(false)
  })

  it('reads configured dual-role email', () => {
    vi.stubEnv('VITE_OPERATOR_DUAL_ROLE_EMAIL', 'ops@example.com')
    expect(dualRoleOperatorEmail()).toBe('ops@example.com')
    expect(isDualRoleOperatorEmail('ops@example.com')).toBe(true)
    vi.unstubAllEnvs()
  })
})

describe('oauthRedirectUrl', () => {
  it('uses current origin with default path', () => {
    expect(oauthRedirectUrl()).toBe(`${window.location.origin}/`)
  })

  it('supports custom return paths', () => {
    expect(oauthRedirectUrl('/invite/abc123')).toBe(
      `${window.location.origin}/invite/abc123`,
    )
  })
})

describe('friendlyAuthError', () => {
  it('maps OAuth secret errors', () => {
    expect(friendlyAuthError('missing OAuth secret')).toContain('Google sign-in')
  })

  it('maps validation errors', () => {
    expect(friendlyAuthError('validation_failed')).toContain('Providers')
  })

  it('returns original message otherwise', () => {
    expect(friendlyAuthError('Custom error')).toBe('Custom error')
  })
})
