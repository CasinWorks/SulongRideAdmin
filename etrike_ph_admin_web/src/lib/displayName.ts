const PLACEHOLDER_NAMES = new Set(['operator', 'admin', 'user'])

export function normalizePersonName(value: string): string {
  return value.trim().replace(/\s+/g, ' ')
}

export function isValidPersonName(value: string): boolean {
  const name = normalizePersonName(value)
  return name.length >= 2 && name.length <= 80
}

export function operatorDisplayName(person: {
  full_name?: string | null
  email?: string | null
}): string {
  const name = person.full_name?.trim()
  if (name) return name
  const email = person.email?.trim()
  if (email) return email.split('@')[0] || 'Operator'
  return 'Operator'
}

/** True when we should prompt the user to choose a display name. */
export function needsOperatorName(
  fullName: string | null | undefined,
  email: string | null | undefined,
): boolean {
  const name = fullName?.trim()
  if (!name || name.length < 2) return true

  const emailLocal = email?.split('@')[0]?.toLowerCase()
  if (emailLocal && name.toLowerCase() === emailLocal) return true
  if (PLACEHOLDER_NAMES.has(name.toLowerCase())) return true

  return false
}
