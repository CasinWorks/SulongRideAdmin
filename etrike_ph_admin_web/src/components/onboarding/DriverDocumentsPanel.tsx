import { useMemo, useState } from 'react'
import { ExternalLink, FileText, X, ZoomIn } from 'lucide-react'
import {
  DOCUMENT_LABELS,
  REQUIRED_DRIVER_DOCUMENTS,
  type DocumentTypeId,
} from '../../lib/onboardingConstants'
import {
  buildDocumentMap,
  documentLabel,
  documentStatusClass,
  documentStatusLabel,
  documentTypesToShow,
  isImageUrl,
  isPdfUrl,
} from '../../lib/documentUtils'
import type { DriverDocumentRow } from '../../types/onboarding'
import { PanelCard } from '../ui/adminPageUi'

type Props = {
  documents: DriverDocumentRow[]
  checklistPercent?: number
  title?: string
  /** Show all required slots, including missing uploads. */
  showMissing?: boolean
}

export function DriverDocumentsPanel({
  documents,
  checklistPercent,
  title = 'Uploaded documents',
  showMissing = true,
}: Props) {
  const docMap = useMemo(() => buildDocumentMap(documents), [documents])
  const types = useMemo(
    () =>
      showMissing
        ? documentTypesToShow(documents, REQUIRED_DRIVER_DOCUMENTS)
        : documents.map((d) => d.doc_type),
    [documents, showMissing],
  )
  const [lightboxUrl, setLightboxUrl] = useState<string | null>(null)
  const [lightboxLabel, setLightboxLabel] = useState('')

  const uploadedCount = REQUIRED_DRIVER_DOCUMENTS.filter((t) => docMap.get(t)?.file_url).length

  function openLightbox(url: string, label: string) {
    setLightboxUrl(url)
    setLightboxLabel(label)
  }

  if (!showMissing && documents.length === 0) {
    return (
      <PanelCard title={title}>
        <p className="py-6 text-center text-sm text-black/45">
          No documents uploaded yet. The driver uploads files from the driver app onboarding flow.
        </p>
      </PanelCard>
    )
  }

  return (
    <>
      <PanelCard
        title={title}
        action={
          checklistPercent != null ? (
            <span className="rounded-full bg-admin-bg px-3 py-1 text-xs font-medium text-black/55">
              {uploadedCount}/{REQUIRED_DRIVER_DOCUMENTS.length} required · {checklistPercent}%
            </span>
          ) : (
            <span className="text-xs text-black/45">{documents.filter((d) => d.file_url).length} on file</span>
          )
        }
      >
        <p className="mb-4 text-sm text-black/55">
          Files uploaded by the driver from the mobile app (Supabase Storage). Click a preview to
          enlarge, or open the original in a new tab.
        </p>
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {types.map((docType) => (
            <DocumentCard
              key={docType}
              docType={docType}
              doc={docMap.get(docType)}
              onPreview={openLightbox}
            />
          ))}
        </div>
      </PanelCard>

      {lightboxUrl ? (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 p-4"
          role="dialog"
          aria-modal="true"
          aria-label={lightboxLabel}
          onClick={() => setLightboxUrl(null)}
        >
          <div
            className="relative max-h-[90vh] max-w-4xl overflow-hidden rounded-2xl bg-white shadow-xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between border-b border-admin-border px-4 py-3">
              <p className="text-sm font-medium text-black/87">{lightboxLabel}</p>
              <button
                type="button"
                className="rounded-lg p-1 text-black/55 hover:bg-admin-bg"
                onClick={() => setLightboxUrl(null)}
                aria-label="Close preview"
              >
                <X size={20} />
              </button>
            </div>
            <div className="max-h-[calc(90vh-56px)] overflow-auto p-4">
              {isPdfUrl(lightboxUrl) ? (
                <iframe
                  title={lightboxLabel}
                  src={lightboxUrl}
                  className="h-[70vh] w-full min-w-[280px] rounded-lg border border-admin-border"
                />
              ) : (
                <img
                  src={lightboxUrl}
                  alt={lightboxLabel}
                  className="mx-auto max-h-[70vh] max-w-full object-contain"
                />
              )}
            </div>
            <div className="border-t border-admin-border px-4 py-3">
              <a
                href={lightboxUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 text-sm font-medium text-admin-accent hover:underline"
              >
                Open original file
                <ExternalLink size={14} />
              </a>
            </div>
          </div>
        </div>
      ) : null}
    </>
  )
}

function DocumentCard({
  docType,
  doc,
  onPreview,
}: {
  docType: DocumentTypeId
  doc: DriverDocumentRow | undefined
  onPreview: (url: string, label: string) => void
}) {
  const label = documentLabel(docType)
  const uploaded = Boolean(doc?.file_url)
  const statusClass = documentStatusClass(doc?.status, uploaded)

  return (
    <article className="flex flex-col overflow-hidden rounded-xl border border-admin-border bg-white">
      <div className="border-b border-admin-border bg-admin-bg/40 px-3 py-2">
        <div className="flex items-start justify-between gap-2">
          <p className="text-sm font-medium text-black/87">{label}</p>
          <span className={`shrink-0 rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide ${statusClass}`}>
            {documentStatusLabel(doc?.status, uploaded)}
          </span>
        </div>
        {doc?.file_name ? (
          <p className="mt-1 truncate text-xs text-black/45" title={doc.file_name}>
            {doc.file_name}
          </p>
        ) : null}
      </div>

      <div className="flex flex-1 flex-col p-3">
        {!uploaded ? (
          <div className="flex min-h-[120px] flex-1 items-center justify-center rounded-lg border border-dashed border-admin-border bg-admin-bg/30 text-xs text-black/40">
            Not uploaded
          </div>
        ) : isImageUrl(doc!.file_url) ? (
          <button
            type="button"
            className="group relative min-h-[120px] overflow-hidden rounded-lg border border-admin-border bg-admin-bg/20"
            onClick={() => onPreview(doc!.file_url!, label)}
          >
            <img
              src={doc!.file_url!}
              alt={label}
              className="h-40 w-full object-contain"
              loading="lazy"
            />
            <span className="absolute inset-0 flex items-center justify-center bg-black/0 opacity-0 transition group-hover:bg-black/25 group-hover:opacity-100">
              <ZoomIn className="text-white" size={28} />
            </span>
          </button>
        ) : isPdfUrl(doc!.file_url) ? (
          <div className="flex min-h-[120px] flex-col items-center justify-center gap-2 rounded-lg border border-admin-border bg-admin-bg/30 p-4">
            <FileText size={32} className="text-admin-accent" />
            <p className="text-xs text-black/55">PDF document</p>
            <button
              type="button"
              className="text-xs font-medium text-admin-accent hover:underline"
              onClick={() => onPreview(doc!.file_url!, label)}
            >
              Preview PDF
            </button>
          </div>
        ) : (
          <div className="flex min-h-[120px] items-center justify-center rounded-lg border border-admin-border bg-admin-bg/30">
            <FileText size={28} className="text-black/35" />
          </div>
        )}

        {doc?.expiry_date ? (
          <p className="mt-2 text-xs text-black/45">Expires {doc.expiry_date}</p>
        ) : null}
        {doc?.admin_notes ? (
          <p className="mt-1 text-xs text-red-700">Note: {doc.admin_notes}</p>
        ) : null}

        {uploaded ? (
          <a
            href={doc!.file_url!}
            target="_blank"
            rel="noopener noreferrer"
            className="mt-3 inline-flex items-center gap-1 text-xs font-medium text-admin-accent hover:underline"
          >
            Open file
            <ExternalLink size={12} />
          </a>
        ) : null}
      </div>
    </article>
  )
}

/** Inline thumbnail used inside onboarding upload rows. */
export function DocumentInlinePreview({
  docType,
  fileUrl,
  fileName,
}: {
  docType: DocumentTypeId
  fileUrl: string | null | undefined
  fileName?: string | null
}) {
  if (!fileUrl) return null
  const label = DOCUMENT_LABELS[docType]

  return (
    <div className="mt-3">
      {fileName ? <p className="mb-1 text-xs text-green-700">Uploaded: {fileName}</p> : null}
      {isImageUrl(fileUrl) ? (
        <a href={fileUrl} target="_blank" rel="noopener noreferrer">
          <img
            src={fileUrl}
            alt={label}
            className="max-h-36 rounded-lg border border-admin-border object-contain hover:opacity-90"
          />
        </a>
      ) : (
        <a
          href={fileUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-1 text-xs font-medium text-admin-accent hover:underline"
        >
          <FileText size={14} />
          View {isPdfUrl(fileUrl) ? 'PDF' : 'file'} ↗
        </a>
      )}
    </div>
  )
}
