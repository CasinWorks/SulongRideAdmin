import { hiringStageLabel, REQUIRED_DRIVER_DOCUMENTS } from './onboardingConstants'
import type {
  DocumentStatusId,
  DocumentTypeId,
  HiringStageId,
} from './onboardingConstants'
import type {
  DriverDocumentRow,
  HiringPipelineState,
  OnboardingTimelineEntry,
  RegistrationDraft,
  VehicleRow,
} from '../types/onboarding'

export function mapVehicle(row: Record<string, unknown>): VehicleRow {
  return {
    id: String(row.id),
    unit_number: String(row.unit_number ?? ''),
    plate_number: String(row.plate_number ?? ''),
    model: row.model != null ? String(row.model) : null,
    status: String(row.status ?? 'available'),
    assigned_driver_id: row.assigned_driver_id != null ? String(row.assigned_driver_id) : null,
    boundary_fee: Number(row.boundary_fee ?? 0),
  }
}

export function mapDriverDocument(row: Record<string, unknown>): DriverDocumentRow {
  return {
    id: String(row.id),
    driver_id: String(row.driver_id),
    doc_type: String(row.doc_type) as DocumentTypeId,
    document_number: row.document_number != null ? String(row.document_number) : null,
    file_url: row.file_url != null ? String(row.file_url) : null,
    file_name: row.file_name != null ? String(row.file_name) : null,
    issue_date: row.issue_date != null ? String(row.issue_date) : null,
    expiry_date: row.expiry_date != null ? String(row.expiry_date) : null,
    status: String(row.status ?? 'pending') as DocumentStatusId,
    admin_notes: row.admin_notes != null ? String(row.admin_notes) : null,
    verified_at: row.verified_at != null ? String(row.verified_at) : null,
    vehicle_id: row.vehicle_id != null ? String(row.vehicle_id) : null,
  }
}

export function mapRegistrationDraft(row: Record<string, unknown>): RegistrationDraft {
  return {
    driver_id: String(row.driver_id),
    current_step: Number(row.current_step ?? 1),
    personal_info: (row.personal_info as Record<string, unknown>) ?? {},
    employment: (row.employment as Record<string, unknown>) ?? {},
    updated_at: row.updated_at != null ? String(row.updated_at) : null,
  }
}

export function mapHiringPipeline(
  row: Record<string, unknown>,
  timeline: OnboardingTimelineEntry[] = [],
): HiringPipelineState {
  const stage = String(row.current_stage ?? 'application') as HiringStageId
  return {
    driver_id: String(row.driver_id),
    stage,
    stage_label: hiringStageLabel(stage),
    pipeline_percent: Number(row.pipeline_percent ?? 0),
    checklist_percent: Number(row.checklist_percent ?? 0),
    interview_at: row.interview_at != null ? String(row.interview_at) : null,
    contract_due_date: row.contract_due_date != null ? String(row.contract_due_date) : null,
    onboarding_due_date: row.onboarding_due_date != null ? String(row.onboarding_due_date) : null,
    timeline,
  }
}

export function mapTimelineEntry(row: Record<string, unknown>): OnboardingTimelineEntry {
  return {
    id: String(row.id),
    created_at: String(row.created_at),
    action: String(row.action),
    summary: String(row.summary),
  }
}

export function computeChecklistPercent(docs: DriverDocumentRow[]): number {
  if (REQUIRED_DRIVER_DOCUMENTS.length === 0) return 0
  let done = 0
  for (const required of REQUIRED_DRIVER_DOCUMENTS) {
    const row = docs.find((d) => d.doc_type === required)
    if (!row?.file_url) continue
    if (['verified', 'pending', 'does_not_expire', 'expiring_soon'].includes(row.status)) {
      done += 1
    }
  }
  return Math.round((done / REQUIRED_DRIVER_DOCUMENTS.length) * 100)
}
