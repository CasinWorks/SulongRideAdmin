import { describe, expect, it } from 'vitest'
import {
  isValidPersonName,
  needsOperatorName,
  normalizePersonName,
  operatorDisplayName,
} from './displayName'

describe('operatorDisplayName', () => {
  it('prefers full_name', () => {
    expect(operatorDisplayName({ full_name: 'Ana Cruz', email: 'a@b.com' })).toBe('Ana Cruz')
  })

  it('falls back to email local part', () => {
    expect(operatorDisplayName({ full_name: '', email: 'juan@example.com' })).toBe('juan')
  })
})

describe('needsOperatorName', () => {
  it('requires a real name', () => {
    expect(needsOperatorName('', 'juan@example.com')).toBe(true)
    expect(needsOperatorName('juan', 'juan@example.com')).toBe(true)
    expect(needsOperatorName('Operator', 'juan@example.com')).toBe(true)
    expect(needsOperatorName('Juan Dela Cruz', 'juan@example.com')).toBe(false)
  })
})

describe('normalizePersonName', () => {
  it('trims and collapses spaces', () => {
    expect(normalizePersonName('  Juan   Cruz  ')).toBe('Juan Cruz')
  })
})

describe('isValidPersonName', () => {
  it('accepts reasonable lengths', () => {
    expect(isValidPersonName('Jo')).toBe(true)
    expect(isValidPersonName('J')).toBe(false)
  })
})
