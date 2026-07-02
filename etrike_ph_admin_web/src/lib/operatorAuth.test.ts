import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest'
import {
  friendlyAuthError,
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

describe('oauthRedirectUrl', () => {
  it('uses current origin', () => {
    expect(oauthRedirectUrl()).toBe(`${window.location.origin}/`)
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
