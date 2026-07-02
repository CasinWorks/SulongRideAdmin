/** Optional: restrict sign-in to `@this-domain` (e.g. casinworks.com). Leave unset to allow any email. */
export function operatorEmailDomain(): string | null {
  const domain = import.meta.env.VITE_OPERATOR_EMAIL_DOMAIN?.trim()
  return domain || null
}

export function isEmailAllowedForOperator(email: string | undefined): boolean {
  const domain = operatorEmailDomain()
  if (!domain || !email) return true
  return email.toLowerCase().endsWith(`@${domain.toLowerCase()}`)
}

/** Where Supabase sends the browser after Google OAuth completes. */
export function oauthRedirectUrl(): string {
  return `${window.location.origin}/`
}
