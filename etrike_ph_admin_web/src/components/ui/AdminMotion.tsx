import type { CSSProperties, ReactNode } from 'react'
import { Link } from 'react-router-dom'
import type { BirthdayPerson } from '../../lib/birthdays'

const STAGGER_MS = 55
const MAX_STAGGER = 6

export function staggerStyle(index: number): CSSProperties {
  const delay = Math.min(index, MAX_STAGGER) * STAGGER_MS
  return { animationDelay: `${delay}ms` }
}

export function FadeIn({
  children,
  className = '',
  index = 0,
}: {
  children: ReactNode
  className?: string
  index?: number
}) {
  return (
    <div className={`admin-fade-up ${className}`} style={staggerStyle(index)}>
      {children}
    </div>
  )
}

export function PageTransition({ children }: { children: ReactNode }) {
  return <div className="admin-page-enter">{children}</div>
}

export function BirthdayNotice({ people }: { people: BirthdayPerson[] }) {
  if (people.length === 0) return null

  const label =
    people.length === 1
      ? `${people[0].name} has a birthday today.`
      : people.length === 2
        ? `${people[0].name} and ${people[1].name} have birthdays today.`
        : `${people
            .slice(0, 2)
            .map((p) => p.name)
            .join(', ')} and ${people.length - 2} more have birthdays today.`

  return (
    <div
      className={[
        'admin-birthday-notice mb-5 flex flex-wrap items-center gap-x-3 gap-y-1',
        'rounded-xl border border-admin-accent/25 bg-white px-4 py-3 text-sm text-black/70 shadow-sm',
      ].join(' ')}
      role="status"
    >
      <span className="admin-birthday-dot h-2 w-2 shrink-0 rounded-full bg-admin-accent" aria-hidden />
      <p className="min-w-0 flex-1">{label}</p>
      {people.length === 1 ? (
        <Link
          to={`/drivers/${people[0].id}`}
          className="shrink-0 text-admin-accent transition hover:text-admin-accent-light"
        >
          View profile
        </Link>
      ) : null}
    </div>
  )
}
