import { useEffect, useState } from 'react'
import {
  DOCUMENT_LABELS,
  REQUIRED_DRIVER_DOCUMENTS,
  type DocumentTypeId,
} from '../../lib/onboardingConstants'
import { GhostButton, PrimaryButton, adminInputCls } from '../ui/AdminUi'

type Props = {
  open: boolean
  driverName: string
  busy?: boolean
  error?: string | null
  onConfirm: (reason: string, requiredDocTypes: DocumentTypeId[]) => void
  onClose: () => void
}

export function RequireDocumentsModal({
  open,
  driverName,
  busy = false,
  error,
  onConfirm,
  onClose,
}: Props) {
  const [reason, setReason] = useState('')
  const [selected, setSelected] = useState<DocumentTypeId[]>([])

  useEffect(() => {
    if (!open) return
    setReason('')
    setSelected([])
  }, [open])

  if (!open) return null

  function toggleDoc(docType: DocumentTypeId) {
    setSelected((prev) =>
      prev.includes(docType) ? prev.filter((t) => t !== docType) : [...prev, docType],
    )
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4">
      <div
        role="dialog"
        aria-modal="true"
        className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-2xl border border-admin-border bg-white p-6 shadow-xl"
      >
        <h3 className="text-lg font-semibold text-black/87">Require documents before booking</h3>
        <p className="mt-2 text-sm text-black/60">
          <strong>{driverName}</strong> will be set to pending, taken offline, and redirected to
          the driver app onboarding flow to upload documents. They cannot go online until you
          approve them again.
        </p>

        <label className="mt-4 block text-sm">
          <span className="font-medium text-black/70">Reason (shown to driver)</span>
          <textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            rows={3}
            placeholder="e.g. PDL expired — upload a new copy"
            className={`${adminInputCls} mt-1 resize-y`}
          />
        </label>

        <fieldset className="mt-4">
          <legend className="text-sm font-medium text-black/70">
            Documents to re-upload (optional)
          </legend>
          <p className="mt-1 text-xs text-black/45">
            Selected items are marked rejected in the app so the driver must replace them. Leave
            empty to keep existing uploads but still block booking until re-approval.
          </p>
          <div className="mt-3 max-h-48 space-y-2 overflow-y-auto rounded-xl border border-admin-border bg-admin-bg p-3">
            {REQUIRED_DRIVER_DOCUMENTS.map((docType) => (
              <label key={docType} className="flex cursor-pointer items-start gap-2 text-sm">
                <input
                  type="checkbox"
                  className="mt-0.5"
                  checked={selected.includes(docType)}
                  onChange={() => toggleDoc(docType)}
                />
                <span>{DOCUMENT_LABELS[docType]}</span>
              </label>
            ))}
          </div>
        </fieldset>

        {error ? <p className="mt-3 text-sm text-red-700">{error}</p> : null}

        <div className="mt-5 flex flex-wrap justify-end gap-2">
          <GhostButton disabled={busy} onClick={onClose}>
            Cancel
          </GhostButton>
          <PrimaryButton
            disabled={busy || reason.trim().length < 3}
            onClick={() => onConfirm(reason.trim(), selected)}
          >
            {busy ? 'Updating…' : 'Set to pending'}
          </PrimaryButton>
        </div>
      </div>
    </div>
  )
}
