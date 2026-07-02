import type { PostgrestError } from '@supabase/supabase-js'

function isPostgrestError(error: unknown): error is PostgrestError {
  return (
    typeof error === 'object' &&
    error !== null &&
    'message' in error &&
    typeof (error as PostgrestError).message === 'string'
  )
}

/** Readable message from Supabase/PostgREST errors for UI display. */
export function supabaseErrorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error && !isPostgrestError(error)) {
    return error.message || fallback
  }
  if (!isPostgrestError(error)) return fallback

  const parts = [error.message]
  if (error.details) parts.push(error.details)
  if (error.hint) parts.push(error.hint)
  const message = parts.filter(Boolean).join(' — ')
  return message || fallback
}

export function throwSupabaseError(error: PostgrestError | null, fallback: string): never {
  if (!error) throw new Error(fallback)
  throw new Error(supabaseErrorMessage(error, fallback))
}
