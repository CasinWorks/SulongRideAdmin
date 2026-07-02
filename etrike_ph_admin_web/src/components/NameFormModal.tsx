import { useState } from 'react'
import { adminInputCls, GhostButton, PrimaryButton } from './ui/AdminUi'
import { isValidPersonName, normalizePersonName } from '../lib/displayName'

type Props = {
  open: boolean
  title: string
  description: string
  initialName?: string
  required?: boolean
  busy?: boolean
  onSave: (name: string) => void | Promise<void>
  onClose?: () => void
}

export function NameFormModal({
  open,
  title,
  description,
  initialName = '',
  required = false,
  busy = false,
  onSave,
  onClose,
}: Props) {
  const [name, setName] = useState(initialName)
  const [error, setError] = useState<string | null>(null)

  if (!open) return null

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    const trimmed = normalizePersonName(name)
    if (!isValidPersonName(trimmed)) {
      setError('Enter your full name (2–80 characters).')
      return
    }
    setError(null)
    await onSave(trimmed)
  }

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/45 p-4">
      <div
        className="w-full max-w-md rounded-2xl border border-admin-border bg-white p-6 shadow-xl"
        role="dialog"
        aria-modal="true"
        aria-labelledby="name-form-title"
      >
        <h2 id="name-form-title" className="text-lg font-semibold text-black/87">
          {title}
        </h2>
        <p className="mt-2 text-sm text-black/55">{description}</p>

        <form onSubmit={(e) => void handleSubmit(e)} className="mt-5 space-y-4">
          <label className="block">
            <span className="text-sm font-medium text-black/70">Full name</span>
            <input
              type="text"
              required
              autoFocus
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Juan Dela Cruz"
              className={adminInputCls}
              maxLength={80}
            />
          </label>
          {error ? (
            <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>
          ) : null}
          <div className="flex justify-end gap-2">
            {!required && onClose ? (
              <GhostButton disabled={busy} onClick={onClose}>
                Cancel
              </GhostButton>
            ) : null}
            <PrimaryButton type="submit" disabled={busy}>
              {busy ? 'Saving…' : 'Save name'}
            </PrimaryButton>
          </div>
        </form>
      </div>
    </div>
  )
}
