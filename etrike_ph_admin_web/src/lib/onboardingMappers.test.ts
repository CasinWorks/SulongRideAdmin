import { describe, expect, it } from 'vitest'
import { REQUIRED_DRIVER_DOCUMENTS } from './onboardingConstants'
import {
  computeChecklistPercent,
  mapDriverDocument,
  mapHiringPipeline,
  mapRegistrationDraft,
  mapVehicle,
} from './onboardingMappers'
import type { DriverDocumentRow } from '../types/onboarding'

describe('onboardingMappers', () => {
  it('maps vehicle rows with defaults', () => {
    const vehicle = mapVehicle({ id: 'v1', unit_number: '12' })
    expect(vehicle.id).toBe('v1')
    expect(vehicle.status).toBe('available')
    expect(vehicle.boundary_fee).toBe(0)
  })

  it('maps driver documents', () => {
    const doc = mapDriverDocument({
      id: 'doc1',
      driver_id: 'd1',
      doc_type: 'pdl',
      status: 'verified',
    })
    expect(doc.doc_type).toBe('pdl')
    expect(doc.status).toBe('verified')
  })

  it('maps registration draft', () => {
    const draft = mapRegistrationDraft({
      driver_id: 'd1',
      current_step: 3,
      personal_info: { first_name: 'Ana' },
    })
    expect(draft.current_step).toBe(3)
    expect(draft.personal_info.first_name).toBe('Ana')
  })

  it('maps hiring pipeline with stage label', () => {
    const pipeline = mapHiringPipeline({ driver_id: 'd1', current_stage: 'onboarding' })
    expect(pipeline.stage).toBe('onboarding')
    expect(pipeline.stage_label).toBe('Onboarding')
  })

  it('computes checklist percent from required documents', () => {
    const docs: DriverDocumentRow[] = REQUIRED_DRIVER_DOCUMENTS.map((docType, index) => ({
      id: String(index),
      driver_id: 'd1',
      doc_type: docType,
      document_number: null,
      file_url: index < 5 ? 'https://example.com/file' : null,
      file_name: index < 5 ? 'file.pdf' : null,
      issue_date: null,
      expiry_date: null,
      status: 'pending',
      admin_notes: null,
      verified_at: null,
      vehicle_id: null,
    }))

    expect(computeChecklistPercent(docs)).toBe(
      Math.round((5 / REQUIRED_DRIVER_DOCUMENTS.length) * 100),
    )
  })

  it('returns zero checklist when no documents uploaded', () => {
    expect(computeChecklistPercent([])).toBe(0)
  })
})
