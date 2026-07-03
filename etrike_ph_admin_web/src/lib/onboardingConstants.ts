export type DocumentTypeId =
  | 'profile_photo'
  | 'valid_id'
  | 'pdl'
  | 'lto_or'
  | 'lto_cr'
  | 'ltfrb_cpc'
  | 'nbi'
  | 'police_clearance'
  | 'barangay_clearance'
  | 'psa_birth'
  | 'medical_cert'
  | 'drug_test'
  | 'contract_signed'

export type DocumentStatusId =
  | 'pending'
  | 'verified'
  | 'rejected'
  | 'expiring_soon'
  | 'expired'
  | 'not_required'
  | 'does_not_expire'

export type HiringStageId =
  | 'application'
  | 'interview_scheduled'
  | 'interview_completed'
  | 'offer_hiring'
  | 'onboarding'
  | 'contract_signing'
  | 'approved_active'

export const DOCUMENT_LABELS: Record<DocumentTypeId, string> = {
  profile_photo: 'Profile photo',
  valid_id: 'Valid government ID',
  pdl: "Professional Driver's License (PDL)",
  lto_or: 'LTO Official Receipt (OR)',
  lto_cr: 'LTO Certificate of Registration (CR)',
  ltfrb_cpc: 'LTFRB Franchise / CPC',
  nbi: 'NBI Clearance',
  police_clearance: 'Police Clearance',
  barangay_clearance: 'Barangay Clearance',
  psa_birth: 'PSA Birth Certificate',
  medical_cert: 'Medical Certificate',
  drug_test: 'Drug Test Result',
  contract_signed: 'Signed employment contract',
}

/** Required for Carmona pilot onboarding approval. */
export const REQUIRED_DRIVER_DOCUMENTS: DocumentTypeId[] = [
  'profile_photo',
  'valid_id',
  'pdl',
  'lto_or',
  'lto_cr',
  'ltfrb_cpc',
  'nbi',
  'police_clearance',
  'barangay_clearance',
  'medical_cert',
  'drug_test',
]

export const DOCUMENTS_BY_STEP: Record<number, DocumentTypeId[]> = {
  1: ['profile_photo', 'valid_id'],
  2: ['pdl', 'lto_or', 'lto_cr', 'ltfrb_cpc'],
  3: ['nbi', 'police_clearance', 'barangay_clearance'],
  4: ['medical_cert', 'drug_test'],
}

export const ONBOARDING_STEP_LABELS = [
  'Applicant',
  'Personal info',
  'License & LTO',
  'Clearances',
  'Health',
  'Employment',
  'Review',
] as const

export const EMPLOYMENT_TYPES = [
  { value: 'contractual', label: 'Contractual' },
  { value: 'permanent', label: 'Regular / Permanent' },
  { value: 'per_trip', label: 'Per trip' },
] as const

export const SHIFT_OPTIONS = ['Day shift', 'Night shift', 'Split shift', 'Flexible'] as const

export const DEFAULT_STATION = 'Carmona Central'

export const STORAGE_BUCKET = 'driver-documents'

export function documentDoesNotExpire(docType: DocumentTypeId): boolean {
  return docType === 'psa_birth'
}

export function hiringStageLabel(stage: HiringStageId): string {
  const labels: Record<HiringStageId, string> = {
    application: 'Application',
    interview_scheduled: 'Interview scheduled',
    interview_completed: 'Interview completed',
    offer_hiring: 'Offer / hiring',
    onboarding: 'Onboarding',
    contract_signing: 'Contract signing',
    approved_active: 'Active',
  }
  return labels[stage] ?? stage
}
