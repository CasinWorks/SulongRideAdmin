import { supabase } from '../lib/supabase'
import {
  DOCUMENT_LABELS,
  documentDoesNotExpire,
  DEFAULT_STATION,
  REQUIRED_DRIVER_DOCUMENTS,
  STORAGE_BUCKET,
} from '../lib/onboardingConstants'
import {
  computeChecklistPercent,
  mapDriverDocument,
  mapHiringPipeline,
  mapRegistrationDraft,
  mapTimelineEntry,
} from '../lib/onboardingMappers'
import { throwSupabaseError, supabaseErrorMessage } from '../lib/supabaseError'
import type { DocumentTypeId } from '../lib/onboardingConstants'
import type {
  DriverDocumentRow,
  EmploymentForm,
  HiringPipelineState,
  OnboardingBundle,
  PersonalInfoForm,
  RegistrationDraft,
  VehicleRow,
} from '../types/onboarding'
import { logAudit } from './audit'
import { auditSummaryDriverRequirementsPending } from '../lib/auditSummary'
import {
  assignVehicleToDriver as fleetAssignVehicle,
  listAvailableVehiclesForDriver,
} from './fleet'

async function logTimeline(
  driverId: string,
  action: string,
  summary: string,
  metadata?: Record<string, unknown>,
): Promise<void> {
  const {
    data: { user },
  } = await supabase.auth.getUser()
  const { error } = await supabase.from('onboarding_timeline').insert({
    driver_id: driverId,
    actor_id: user?.id ?? null,
    action,
    summary,
    metadata: metadata ?? {},
  })
  if (error) console.warn('Timeline insert failed:', error.message)
}

async function syncChecklistPercent(driverId: string): Promise<number> {
  const docs = await listDocuments(driverId)
  const pct = computeChecklistPercent(docs)
  await supabase.from('driver_hiring_pipeline').upsert(
    {
      driver_id: driverId,
      checklist_percent: pct,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'driver_id' },
  )
  return pct
}

export async function listAvailableVehicles(forDriverId?: string): Promise<VehicleRow[]> {
  const rows = await listAvailableVehiclesForDriver(forDriverId)
  return rows.map((v) => ({
    id: v.id,
    unit_number: v.unit_number,
    plate_number: v.plate_number,
    model: v.model,
    status: v.status,
    assigned_driver_id: v.assigned_driver_id,
    boundary_fee: v.boundary_fee,
  }))
}

export async function listDocuments(driverId: string): Promise<DriverDocumentRow[]> {
  const { data, error } = await supabase
    .from('driver_documents')
    .select('*')
    .eq('driver_id', driverId)
  if (error) throwSupabaseError(error, 'Failed to load documents')
  return (data ?? []).map((row) => mapDriverDocument(row as Record<string, unknown>))
}

export async function fetchDraft(driverId: string): Promise<RegistrationDraft | null> {
  const { data, error } = await supabase
    .from('driver_registration_drafts')
    .select('*')
    .eq('driver_id', driverId)
    .maybeSingle()
  if (error) throwSupabaseError(error, 'Failed to load draft')
  return data ? mapRegistrationDraft(data as Record<string, unknown>) : null
}

export async function fetchPipeline(driverId: string): Promise<HiringPipelineState | null> {
  const { data, error } = await supabase
    .from('driver_hiring_pipeline')
    .select('*')
    .eq('driver_id', driverId)
    .maybeSingle()
  if (error) throwSupabaseError(error, 'Failed to load pipeline')

  const timelineRows = await supabase
    .from('onboarding_timeline')
    .select('*')
    .eq('driver_id', driverId)
    .order('created_at', { ascending: false })
    .limit(20)

  const timeline = (timelineRows.data ?? []).map((row) =>
    mapTimelineEntry(row as Record<string, unknown>),
  )

  return data ? mapHiringPipeline(data as Record<string, unknown>, timeline) : null
}

export async function fetchOnboardingBundle(driverId: string): Promise<OnboardingBundle> {
  const [draft, pipeline, documents] = await Promise.all([
    fetchDraft(driverId),
    fetchPipeline(driverId),
    listDocuments(driverId),
  ])
  return {
    draft,
    pipeline,
    documents,
    checklist_percent: computeChecklistPercent(documents),
  }
}

export async function ensurePipeline(driverId: string): Promise<void> {
  const { data } = await supabase
    .from('driver_hiring_pipeline')
    .select('id')
    .eq('driver_id', driverId)
    .maybeSingle()
  if (data) return

  const { error } = await supabase.from('driver_hiring_pipeline').insert({
    driver_id: driverId,
    current_stage: 'onboarding',
    stage_status: 'in_progress',
  })
  if (error) throwSupabaseError(error, 'Failed to create pipeline')
}

export async function savePersonalInfo(
  driverId: string,
  form: PersonalInfoForm,
): Promise<void> {
  const fullName = [form.first_name.trim(), form.last_name.trim()].filter(Boolean).join(' ')
  const personalInfo = {
    first_name: form.first_name.trim(),
    last_name: form.last_name.trim(),
    contact: form.contact.trim(),
    email: form.email.trim(),
    emergency_contact: form.emergency_contact.trim(),
  }

  const { error: driverError } = await supabase
    .from('drivers')
    .update({
      full_name: fullName,
      phone: form.contact.trim(),
      emergency_contact: form.emergency_contact.trim(),
    })
    .eq('id', driverId)
  if (driverError) throwSupabaseError(driverError, 'Failed to update driver profile')

  const { error: draftError } = await supabase.from('driver_registration_drafts').upsert({
    driver_id: driverId,
    current_step: 2,
    personal_info: personalInfo,
    updated_at: new Date().toISOString(),
  })
  if (draftError) throwSupabaseError(draftError, 'Failed to save draft')

  await ensurePipeline(driverId)
  await logTimeline(driverId, 'personal_info_saved', 'Personal information updated')
}

export async function saveEmployment(driverId: string, form: EmploymentForm): Promise<void> {
  const vehicle = (await listAvailableVehicles(driverId)).find((v) => v.id === form.vehicle_id)
  if (!vehicle) throw new Error('Select a company e-trike unit')

  const employment = {
    vehicle_id: form.vehicle_id,
    type: form.employment_type,
    shift: form.shift_schedule,
    start_date: form.start_date,
    station: form.station,
  }

  const { error: driverError } = await supabase
    .from('drivers')
    .update({
      employment_type: form.employment_type,
      shift_schedule: form.shift_schedule,
      start_date: form.start_date,
      station: form.station || DEFAULT_STATION,
    })
    .eq('id', driverId)
  if (driverError) throwSupabaseError(driverError, 'Failed to update employment')

  await fleetAssignVehicle({
    vehicle_id: vehicle.id,
    driver_id: driverId,
    notes: `Onboarding employment step — unit ${vehicle.unit_number}`,
  })

  const { error: draftError } = await supabase.from('driver_registration_drafts').upsert({
    driver_id: driverId,
    current_step: 6,
    employment,
    updated_at: new Date().toISOString(),
  })
  if (draftError) throwSupabaseError(draftError, 'Failed to save employment draft')

  await logTimeline(driverId, 'employment_saved', `Assigned unit ${vehicle.unit_number}`)
}

export async function assignVehicle(
  vehicleId: string,
  driverId: string,
  _plateNumber: string,
): Promise<void> {
  await fleetAssignVehicle({ vehicle_id: vehicleId, driver_id: driverId })
}

export async function uploadDocument(
  driverId: string,
  docType: DocumentTypeId,
  file: File,
  expiryDate?: string,
): Promise<DriverDocumentRow> {
  const path = `${driverId}/${docType}/${file.name}`
  const { error: uploadError } = await supabase.storage
    .from(STORAGE_BUCKET)
    .upload(path, file, { upsert: true })
  if (uploadError) {
    throw new Error(supabaseErrorMessage(uploadError, `Failed to upload ${DOCUMENT_LABELS[docType]}`))
  }

  const { data: urlData } = supabase.storage.from(STORAGE_BUCKET).getPublicUrl(path)
  const status = documentDoesNotExpire(docType) ? 'does_not_expire' : 'pending'

  const payload: Record<string, unknown> = {
    driver_id: driverId,
    doc_type: docType,
    file_url: urlData.publicUrl,
    file_name: file.name,
    status,
    updated_at: new Date().toISOString(),
  }
  if (expiryDate) payload.expiry_date = expiryDate

  const { data, error } = await supabase
    .from('driver_documents')
    .upsert(payload, { onConflict: 'driver_id,doc_type' })
    .select('*')
    .single()
  if (error) throwSupabaseError(error, 'Failed to save document record')

  await syncChecklistPercent(driverId)
  await logAudit({
    action: 'driver.document.upload',
    entityType: 'driver_documents',
    entityId: driverId,
    summary: `Uploaded ${DOCUMENT_LABELS[docType]}`,
    metadata: { doc_type: docType },
  })

  return mapDriverDocument(data as Record<string, unknown>)
}

export async function reviewDriverDocument(
  driverId: string,
  docType: DocumentTypeId,
  decision: 'verified' | 'rejected',
  options?: { note?: string; driverName?: string },
): Promise<void> {
  const label = DOCUMENT_LABELS[docType]
  const docs = await listDocuments(driverId)
  const existing = docs.find((d) => d.doc_type === docType)
  if (!existing?.file_url) {
    throw new Error(`No upload on file for ${label}`)
  }

  const {
    data: { user },
  } = await supabase.auth.getUser()
  const now = new Date().toISOString()

  if (decision === 'verified') {
    const status = documentDoesNotExpire(docType) ? 'does_not_expire' : 'verified'
    const { error } = await supabase
      .from('driver_documents')
      .update({
        status,
        admin_notes: null,
        verified_by: user?.id ?? null,
        verified_at: now,
        updated_at: now,
      })
      .eq('driver_id', driverId)
      .eq('doc_type', docType)
    if (error) throwSupabaseError(error, `Failed to verify ${label}`)

    await syncChecklistPercent(driverId)
    await logTimeline(driverId, 'document_verified', `${label} verified`)
    await logAudit({
      action: 'driver.document.verify',
      entityType: 'driver_documents',
      entityId: driverId,
      summary: `Verified ${label}${options?.driverName ? ` — ${options.driverName}` : ''}`,
      metadata: { doc_type: docType, status },
    })
    return
  }

  const note = options?.note?.trim() ?? ''
  if (note.length < 3) {
    throw new Error('Enter a rejection reason for the driver (at least 3 characters)')
  }

  const { error: docError } = await supabase
    .from('driver_documents')
    .update({
      status: 'rejected',
      admin_notes: note,
      verified_by: null,
      verified_at: null,
      updated_at: now,
    })
    .eq('driver_id', driverId)
    .eq('doc_type', docType)
  if (docError) throwSupabaseError(docError, `Failed to reject ${label}`)

  const { data: driverRow } = await supabase
    .from('drivers')
    .select('approval_status, full_name')
    .eq('id', driverId)
    .maybeSingle()

  if (driverRow?.approval_status === 'approved') {
    const { error: driverError } = await supabase
      .from('drivers')
      .update({
        approval_status: 'pending',
        is_online: false,
        is_available: false,
      })
      .eq('id', driverId)
    if (driverError) throwSupabaseError(driverError, 'Failed to set driver pending')

    await ensurePipeline(driverId)
    await supabase
      .from('driver_hiring_pipeline')
      .update({
        current_stage: 'onboarding',
        stage_status: 'in_progress',
        updated_at: now,
      })
      .eq('driver_id', driverId)
  }

  await syncChecklistPercent(driverId)
  await logTimeline(driverId, 'document_rejected', `${label} rejected — ${note}`, {
    doc_type: docType,
  })
  await logAudit({
    action: 'driver.document.reject',
    entityType: 'driver_documents',
    entityId: driverId,
    summary: `Rejected ${label}${options?.driverName ? ` — ${options.driverName}` : ''} — ${note}`,
    metadata: { doc_type: docType, note },
  })
}

export async function approveOnboarding(driverId: string, notes?: string): Promise<void> {
  const docs = await listDocuments(driverId)
  const checklist = computeChecklistPercent(docs)
  if (checklist < 100) {
    throw new Error(`Document checklist incomplete (${checklist}%). Upload all required documents.`)
  }

  const pendingReview = docs.filter(
    (d) =>
      REQUIRED_DRIVER_DOCUMENTS.includes(d.doc_type) &&
      d.file_url &&
      d.status !== 'verified' &&
      d.status !== 'does_not_expire',
  )
  if (pendingReview.length > 0) {
    throw new Error(
      `Verify all compliance documents before approving (${pendingReview.length} still pending review).`,
    )
  }

  const rejected = docs.filter(
    (d) => REQUIRED_DRIVER_DOCUMENTS.includes(d.doc_type) && d.status === 'rejected',
  )
  if (rejected.length > 0) {
    throw new Error('Some documents are rejected. Ask the driver to re-upload before approving.')
  }

  const { error: driverError } = await supabase
    .from('drivers')
    .update({ approval_status: 'approved' })
    .eq('id', driverId)
  if (driverError) throwSupabaseError(driverError, 'Failed to approve driver')

  await ensurePipeline(driverId)
  const { error: pipelineError } = await supabase
    .from('driver_hiring_pipeline')
    .update({
      current_stage: 'approved_active',
      stage_status: 'completed',
      pipeline_percent: 100,
      checklist_percent: checklist,
      updated_at: new Date().toISOString(),
    })
    .eq('driver_id', driverId)
  if (pipelineError) throwSupabaseError(pipelineError, 'Failed to update pipeline')

  await logTimeline(driverId, 'approved', 'Driver onboarding approved')
  await logAudit({
    action: 'driver.onboarding.approve',
    entityType: 'drivers',
    entityId: driverId,
    summary: 'Driver onboarding approved',
    metadata: notes ? { notes } : {},
  })
}

export async function rejectOnboarding(driverId: string, reason: string): Promise<void> {
  const trimmed = reason.trim()
  if (trimmed.length < 3) throw new Error('Enter a rejection reason')

  const { error } = await supabase
    .from('drivers')
    .update({
      approval_status: 'rejected',
      is_online: false,
      is_available: false,
    })
    .eq('id', driverId)
  if (error) throwSupabaseError(error, 'Failed to reject driver')

  await logTimeline(driverId, 'rejected', trimmed)
  await logAudit({
    action: 'driver.onboarding.reject',
    entityType: 'drivers',
    entityId: driverId,
    summary: `Driver onboarding rejected — ${trimmed}`,
  })
}

/** Pull an approved driver back to pending so they must re-upload docs before booking. */
export async function setDriverPendingRequirements(
  driverId: string,
  options: {
    reason: string
    requiredDocTypes?: DocumentTypeId[]
    driverName?: string
  },
): Promise<void> {
  const reason = options.reason.trim()
  if (reason.length < 3) throw new Error('Enter a reason the driver will see')

  const { error: driverError } = await supabase
    .from('drivers')
    .update({
      approval_status: 'pending',
      is_online: false,
      is_available: false,
    })
    .eq('id', driverId)
  if (driverError) throwSupabaseError(driverError, 'Failed to set driver pending')

  await ensurePipeline(driverId)
  const { error: pipelineError } = await supabase
    .from('driver_hiring_pipeline')
    .update({
      current_stage: 'onboarding',
      stage_status: 'in_progress',
      updated_at: new Date().toISOString(),
    })
    .eq('driver_id', driverId)
  if (pipelineError) throwSupabaseError(pipelineError, 'Failed to update hiring pipeline')

  const docTypes = options.requiredDocTypes ?? []
  if (docTypes.length > 0) {
    for (const docType of docTypes) {
      const { error: docError } = await supabase
        .from('driver_documents')
        .update({
          status: 'rejected',
          updated_at: new Date().toISOString(),
        })
        .eq('driver_id', driverId)
        .eq('doc_type', docType)
      if (docError) throwSupabaseError(docError, `Failed to mark ${docType} for re-upload`)
    }
    await syncChecklistPercent(driverId)
  }

  await logTimeline(driverId, 'requirements_pending', reason, {
    required_doc_types: docTypes,
  })

  await logAudit({
    action: 'driver.requirements_pending',
    entityType: 'drivers',
    entityId: driverId,
    summary: auditSummaryDriverRequirementsPending(options.driverName ?? driverId, reason),
    metadata: {
      reason,
      required_doc_types: docTypes,
    },
  })
}

export async function saveDraftStep(driverId: string, currentStep: number): Promise<void> {
  await supabase.from('driver_registration_drafts').upsert({
    driver_id: driverId,
    current_step: currentStep,
    updated_at: new Date().toISOString(),
  })
}
