import type { DocumentStatusId, DocumentTypeId, HiringStageId } from '../lib/onboardingConstants'

export type VehicleRow = {
  id: string
  unit_number: string
  plate_number: string
  model: string | null
  status: string
  assigned_driver_id: string | null
  boundary_fee: number
}

export type DriverDocumentRow = {
  id: string
  driver_id: string
  doc_type: DocumentTypeId
  document_number: string | null
  file_url: string | null
  file_name: string | null
  issue_date: string | null
  expiry_date: string | null
  status: DocumentStatusId
  admin_notes: string | null
  verified_at: string | null
  vehicle_id: string | null
}

export type RegistrationDraft = {
  driver_id: string
  current_step: number
  personal_info: Record<string, unknown>
  employment: Record<string, unknown>
  updated_at: string | null
}

export type OnboardingTimelineEntry = {
  id: string
  created_at: string
  action: string
  summary: string
}

export type HiringPipelineState = {
  driver_id: string
  stage: HiringStageId
  stage_label: string
  pipeline_percent: number
  checklist_percent: number
  interview_at: string | null
  contract_due_date: string | null
  onboarding_due_date: string | null
  timeline: OnboardingTimelineEntry[]
}

export type PersonalInfoForm = {
  first_name: string
  last_name: string
  contact: string
  email: string
  emergency_contact: string
}

export type EmploymentForm = {
  vehicle_id: string
  employment_type: string
  shift_schedule: string
  start_date: string
  station: string
}

export type OnboardingBundle = {
  draft: RegistrationDraft | null
  pipeline: HiringPipelineState | null
  documents: DriverDocumentRow[]
  checklist_percent: number
}
