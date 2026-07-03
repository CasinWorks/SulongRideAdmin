import type { DocumentStatusId, DocumentTypeId } from './onboardingConstants'
import { DOCUMENT_LABELS } from './onboardingConstants'
import type { DriverDocumentRow } from '../types/onboarding'

export function isImageUrl(url: string | null | undefined): boolean {
  if (!url) return false
  return /\.(jpe?g|png|webp|gif|heic)(\?|$)/i.test(url)
}

export function isPdfUrl(url: string | null | undefined): boolean {
  if (!url) return false
  return /\.pdf(\?|$)/i.test(url) || url.toLowerCase().includes('application/pdf')
}

export function documentStatusLabel(status: DocumentStatusId | undefined, uploaded: boolean): string {
  if (!uploaded) return 'Missing'
  return (
    {
      pending: 'Pending review',
      verified: 'Verified',
      rejected: 'Rejected',
      expiring_soon: 'Expiring soon',
      expired: 'Expired',
      not_required: 'Not required',
      does_not_expire: 'On file',
    }[status ?? 'pending'] ?? status ?? 'Pending'
  )
}

export function documentStatusClass(status: DocumentStatusId | undefined, uploaded: boolean): string {
  if (!uploaded) return 'bg-black/8 text-black/45'
  switch (status) {
    case 'verified':
    case 'does_not_expire':
      return 'bg-green-100 text-green-800'
    case 'rejected':
    case 'expired':
      return 'bg-red-100 text-red-800'
    case 'expiring_soon':
      return 'bg-amber-100 text-amber-900'
    default:
      return 'bg-sky-100 text-sky-900'
  }
}

export function buildDocumentMap(documents: DriverDocumentRow[]): Map<DocumentTypeId, DriverDocumentRow> {
  const map = new Map<DocumentTypeId, DriverDocumentRow>()
  for (const doc of documents) map.set(doc.doc_type, doc)
  return map
}

export function documentTypesToShow(
  documents: DriverDocumentRow[],
  required: DocumentTypeId[],
): DocumentTypeId[] {
  const seen = new Set<DocumentTypeId>(required)
  const extras = documents.map((d) => d.doc_type).filter((t) => !seen.has(t))
  return [...required, ...extras]
}

export function documentLabel(docType: DocumentTypeId): string {
  return DOCUMENT_LABELS[docType] ?? docType
}
