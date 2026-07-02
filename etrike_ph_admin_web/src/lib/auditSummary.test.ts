import { describe, expect, it } from 'vitest'
import {
  auditSummaryFareRates,
  auditSummaryLeaveReview,
  auditSummaryOperatorAction,
  auditSummaryUpdatedFareSchedule,
  auditSummaryDriverApproval,
  sanitizeAuditText,
} from './auditSummary'

describe('sanitizeAuditText', () => {
  it('strips quotes and control characters', () => {
    expect(sanitizeAuditText(`hello"; DROP TABLE--`)).toBe('hello DROP TABLE--')
  })

  it('truncates to max length', () => {
    expect(sanitizeAuditText('a'.repeat(200), 10)).toHaveLength(10)
  })
})

describe('auditSummaryUpdatedFareSchedule', () => {
  it('includes sanitized label when present', () => {
    expect(auditSummaryUpdatedFareSchedule('Peak hours')).toBe(
      'Updated scheduled fare (Peak hours)',
    )
  })

  it('falls back when label is empty after sanitization', () => {
    expect(auditSummaryUpdatedFareSchedule('   ')).toBe('Updated scheduled fare')
  })
})

describe('auditSummaryFareRates', () => {
  it('formats fare amounts', () => {
    const summary = auditSummaryFareRates('Default fare updated', {
      base: 40,
      perKm: 12,
      minimum: 35,
    })
    expect(summary).toContain('Default fare updated')
    expect(summary).toContain('₱40')
    expect(summary).toContain('₱12')
    expect(summary).toContain('₱35')
  })
})

describe('auditSummaryOperatorAction', () => {
  it('sanitizes identifier and detail', () => {
    const summary = auditSummaryOperatorAction(
      'Operator approval updated',
      'ops@example.com',
      'approved',
    )
    expect(summary).toContain('Operator approval updated')
    expect(summary).toContain('ops@example.com')
    expect(summary).toContain('approved')
  })
})

describe('auditSummaryDriverApproval', () => {
  it('includes sanitized status', () => {
    expect(auditSummaryDriverApproval('approved')).toBe('Driver approval set to approved')
  })
})

describe('auditSummaryLeaveReview', () => {
  it('includes sanitized status', () => {
    expect(auditSummaryLeaveReview('rejected')).toBe('Leave request rejected')
  })
})
