import type { ReactNode } from 'react'

export function StatCard({
  label,
  value,
  hint,
}: {
  label: string
  value: string
  hint?: string
}) {
  return (
    <div className="rounded-2xl border border-admin-border bg-white p-5 shadow-sm">
      <p className="text-sm text-black/55">{label}</p>
      <p className="mt-1 text-2xl font-semibold text-black/87">{value}</p>
      {hint ? <p className="mt-1 text-xs text-black/45">{hint}</p> : null}
    </div>
  )
}

export function PanelCard({
  title,
  children,
  action,
}: {
  title: string
  children: ReactNode
  action?: ReactNode
}) {
  return (
    <div className="rounded-2xl border border-admin-border bg-white p-5 shadow-sm">
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <h3 className="text-base font-semibold text-black/87">{title}</h3>
        {action ? <div className="w-full sm:w-auto">{action}</div> : null}
      </div>
      {children}
    </div>
  )
}

export function StatusPill({ status }: { status: string }) {
  const cls =
    status === 'approved'
      ? 'bg-green-100 text-green-800'
      : status === 'pending'
        ? 'bg-amber-100 text-amber-800'
        : status === 'rejected'
          ? 'bg-red-100 text-red-800'
          : 'bg-gray-100 text-gray-700'
  return (
    <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium capitalize ${cls}`}>
      {status}
    </span>
  )
}

export function PrimaryButton({
  children,
  onClick,
  disabled,
  type = 'button',
}: {
  children: ReactNode
  onClick?: () => void
  disabled?: boolean
  type?: 'button' | 'submit'
}) {
  return (
    <button
      type={type}
      disabled={disabled}
      onClick={onClick}
      className="rounded-xl bg-admin-accent px-5 py-2.5 text-sm font-medium text-white transition hover:bg-admin-accent-light disabled:opacity-50"
    >
      {children}
    </button>
  )
}

export function GhostButton({
  children,
  onClick,
  disabled,
}: {
  children: ReactNode
  onClick?: () => void
  disabled?: boolean
}) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className="rounded-xl border border-admin-border bg-white px-4 py-2 text-sm font-medium text-black/70 hover:bg-admin-bg disabled:opacity-50"
    >
      {children}
    </button>
  )
}

export function LoadingState({ label = 'Loading…' }: { label?: string }) {
  return (
    <div className="flex min-h-[200px] items-center justify-center text-black/50">
      {label}
    </div>
  )
}

export function ErrorState({ message }: { message: string }) {
  return (
    <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
      {message}
    </div>
  )
}
