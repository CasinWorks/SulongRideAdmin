import type { ReactNode } from 'react'
import { GhostButton, adminInputCls } from './AdminUi'

type ConfirmPermanentDeleteModalProps = {
  open: boolean
  title: string
  description: ReactNode
  confirmLabel: string
  confirmToken: string
  tokenLabel: string
  tokenValue: string
  busy?: boolean
  onTokenChange: (value: string) => void
  onConfirm: () => void
  onClose: () => void
}

export function ConfirmPermanentDeleteModal({
  open,
  title,
  description,
  confirmLabel,
  confirmToken,
  tokenLabel,
  tokenValue,
  busy = false,
  onTokenChange,
  onConfirm,
  onClose,
}: ConfirmPermanentDeleteModalProps) {
  if (!open) return null

  const canConfirm = tokenValue.trim() === confirmToken && !busy

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4">
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="delete-dialog-title"
        className="w-full max-w-md rounded-2xl border border-red-200 bg-white p-6 shadow-xl"
      >
        <h3 id="delete-dialog-title" className="text-lg font-semibold text-red-800">
          {title}
        </h3>
        <div className="mt-2 text-sm text-black/65">{description}</div>
        <label className="mt-4 block text-sm">
          <span className="font-medium text-black/70">
            Type <strong>{tokenLabel}</strong> to confirm
          </span>
          <input
            className={adminInputCls}
            value={tokenValue}
            onChange={(e) => onTokenChange(e.target.value)}
            placeholder={confirmToken}
            autoComplete="off"
          />
        </label>
        <div className="mt-5 flex flex-wrap justify-end gap-2">
          <GhostButton disabled={busy} onClick={onClose}>
            Cancel
          </GhostButton>
          <button
            type="button"
            disabled={!canConfirm}
            onClick={onConfirm}
            className="rounded-xl bg-red-600 px-5 py-2.5 text-sm font-medium text-white disabled:opacity-50"
          >
            {busy ? 'Deleting…' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}
