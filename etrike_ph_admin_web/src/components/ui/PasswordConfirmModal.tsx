import { GhostButton, adminInputCls } from './AdminUi'

type PasswordConfirmModalProps = {
  open: boolean
  title: string
  description: string
  confirmLabel?: string
  password: string
  busy?: boolean
  error?: string | null
  onPasswordChange: (value: string) => void
  onConfirm: () => void
  onClose: () => void
}

export function PasswordConfirmModal({
  open,
  title,
  description,
  confirmLabel = 'Confirm',
  password,
  busy = false,
  error,
  onPasswordChange,
  onConfirm,
  onClose,
}: PasswordConfirmModalProps) {
  if (!open) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4">
      <div
        role="dialog"
        aria-modal="true"
        className="w-full max-w-md rounded-2xl border border-admin-border bg-white p-6 shadow-xl"
      >
        <h3 className="text-lg font-semibold text-black/87">{title}</h3>
        <p className="mt-2 text-sm text-black/60">{description}</p>
        <label className="mt-4 block text-sm">
          <span className="font-medium text-black/70">Your operator password</span>
          <input
            type="password"
            autoComplete="current-password"
            className={adminInputCls}
            value={password}
            onChange={(e) => onPasswordChange(e.target.value)}
          />
        </label>
        {error ? <p className="mt-2 text-sm text-red-700">{error}</p> : null}
        <div className="mt-5 flex flex-wrap justify-end gap-2">
          <GhostButton disabled={busy} onClick={onClose}>
            Cancel
          </GhostButton>
          <button
            type="button"
            disabled={busy || !password.trim()}
            onClick={onConfirm}
            className="rounded-xl bg-admin-accent px-5 py-2.5 text-sm font-medium text-white disabled:opacity-50"
          >
            {busy ? 'Verifying…' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}
