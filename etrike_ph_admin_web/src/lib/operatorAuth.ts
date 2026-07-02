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

export function friendlyAuthError(message: string): string {
  if (message.includes('missing OAuth secret')) {
    return 'Google sign-in is not fully configured in Supabase. Open Authentication → Providers → Google and paste both the Client ID and Client Secret from Google Cloud Console, then Save.'
  }
  if (message.includes('validation_failed')) {
    return 'Sign-in configuration error. Check Supabase Authentication → Providers → Google.'
  }
  return message
}
