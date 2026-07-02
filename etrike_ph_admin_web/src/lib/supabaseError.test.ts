import { describe, expect, it } from 'vitest'
import type { PostgrestError } from '@supabase/supabase-js'
import { supabaseErrorMessage, throwSupabaseError } from './supabaseError'

function pgError(overrides: Partial<PostgrestError>): PostgrestError {
  return {
    message: 'main',
    details: '',
    hint: '',
    code: 'P0001',
    name: 'PostgrestError',
    toJSON: () => ({
      name: 'PostgrestError',
      message: overrides.message ?? 'main',
      details: overrides.details ?? '',
      hint: overrides.hint ?? '',
      code: overrides.code ?? 'P0001',
    }),
    ...overrides,
  }
}

describe('supabaseErrorMessage', () => {
  it('returns fallback for unknown errors', () => {
    expect(supabaseErrorMessage(null, 'fallback')).toBe('fallback')
  })

  it('returns Error message for generic errors', () => {
    expect(supabaseErrorMessage(new Error('boom'), 'fallback')).toBe('boom')
  })

  it('combines PostgREST fields', () => {
    const message = supabaseErrorMessage(
      pgError({ message: 'main', details: 'detail', hint: 'hint' }),
      'fallback',
    )
    expect(message).toContain('main')
    expect(message).toContain('detail')
    expect(message).toContain('hint')
  })
})

describe('throwSupabaseError', () => {
  it('throws fallback when error is null', () => {
    expect(() => throwSupabaseError(null, 'failed')).toThrow('failed')
  })

  it('throws readable message from PostgREST error', () => {
    expect(() =>
      throwSupabaseError(pgError({ message: 'duplicate' }), 'failed'),
    ).toThrow('duplicate')
  })
})
