import { supabase } from '../lib/supabase'
import { throwSupabaseError } from '../lib/supabaseError'
import { computePayrollAmounts, parseSssBrackets } from '../lib/payrollCalculator'
import { logAudit } from './audit'
import type {
  CashAdvanceRow,
  PayrollDeductionConfig,
  PayrollDeductionConfigInput,
  PayrollPreview,
  PayrollRecordRow,
} from '../types/payroll'

function mapConfig(row: Record<string, unknown>): PayrollDeductionConfig {
  return {
    id: String(row.id),
    name: String(row.name ?? 'Config'),
    effective_from: String(row.effective_from ?? ''),
    is_active: Boolean(row.is_active ?? true),
    sss_brackets: parseSssBrackets(row.sss_brackets),
    philhealth_employee_rate: Number(row.philhealth_employee_rate ?? 0.025),
    philhealth_min_contribution: Number(row.philhealth_min_contribution ?? 500),
    philhealth_max_contribution: Number(row.philhealth_max_contribution ?? 5000),
    pagibig_employee_rate: Number(row.pagibig_employee_rate ?? 0.02),
    pagibig_min_contribution: Number(row.pagibig_min_contribution ?? 200),
    pagibig_max_contribution: Number(row.pagibig_max_contribution ?? 200),
    notes: row.notes != null ? String(row.notes) : null,
    created_at: String(row.created_at ?? ''),
    updated_at: String(row.updated_at ?? ''),
  }
}

function mapCashAdvance(row: Record<string, unknown>): CashAdvanceRow {
  return {
    id: String(row.id),
    driver_id: String(row.driver_id),
    amount: Number(row.amount ?? 0),
    balance_remaining: Number(row.balance_remaining ?? 0),
    reason: row.reason != null ? String(row.reason) : null,
    status: (row.status as CashAdvanceRow['status']) ?? 'open',
    issued_at: String(row.issued_at ?? ''),
    issued_by: row.issued_by != null ? String(row.issued_by) : null,
    settled_at: row.settled_at != null ? String(row.settled_at) : null,
    created_at: String(row.created_at ?? ''),
    updated_at: String(row.updated_at ?? ''),
  }
}

function mapPayrollRecord(row: Record<string, unknown>): PayrollRecordRow {
  return {
    id: String(row.id),
    driver_id: String(row.driver_id),
    period_start: String(row.period_start ?? ''),
    period_end: String(row.period_end ?? ''),
    trip_count: Number(row.trip_count ?? 0),
    total_fares: Number(row.total_fares ?? 0),
    shift_days: Number(row.shift_days ?? 0),
    boundary_rate: Number(row.boundary_rate ?? 0),
    boundary_total: Number(row.boundary_total ?? 0),
    gross_pay: Number(row.gross_pay ?? 0),
    sss_deduction: Number(row.sss_deduction ?? 0),
    philhealth_deduction: Number(row.philhealth_deduction ?? 0),
    pagibig_deduction: Number(row.pagibig_deduction ?? 0),
    cash_advance_deduction: Number(row.cash_advance_deduction ?? 0),
    other_deductions: Number(row.other_deductions ?? 0),
    net_pay: Number(row.net_pay ?? 0),
    vehicle_id: row.vehicle_id != null ? String(row.vehicle_id) : null,
    status: (row.status as PayrollRecordRow['status']) ?? 'draft',
    notes: row.notes != null ? String(row.notes) : null,
    deduction_config_id: row.deduction_config_id != null ? String(row.deduction_config_id) : null,
    created_by: row.created_by != null ? String(row.created_by) : null,
    finalized_at: row.finalized_at != null ? String(row.finalized_at) : null,
    paid_at: row.paid_at != null ? String(row.paid_at) : null,
    created_at: String(row.created_at ?? ''),
    updated_at: String(row.updated_at ?? ''),
  }
}

function periodEndIso(periodEnd: string): string {
  return `${periodEnd}T23:59:59.999Z`
}

function periodStartIso(periodStart: string): string {
  return `${periodStart}T00:00:00.000Z`
}

export async function fetchActiveDeductionConfig(): Promise<PayrollDeductionConfig | null> {
  const { data, error } = await supabase
    .from('payroll_deduction_configs')
    .select('*')
    .eq('is_active', true)
    .order('effective_from', { ascending: false })
    .limit(1)
    .maybeSingle()
  if (error) throwSupabaseError(error, 'Failed to load deduction config')
  return data ? mapConfig(data as Record<string, unknown>) : null
}

export async function listDeductionConfigs(): Promise<PayrollDeductionConfig[]> {
  const { data, error } = await supabase
    .from('payroll_deduction_configs')
    .select('*')
    .order('effective_from', { ascending: false })
  if (error) throwSupabaseError(error, 'Failed to load deduction configs')
  return (data ?? []).map((r) => mapConfig(r as Record<string, unknown>))
}

export async function updateDeductionConfig(
  id: string,
  input: PayrollDeductionConfigInput,
): Promise<PayrollDeductionConfig> {
  const now = new Date().toISOString()
  const { data, error } = await supabase
    .from('payroll_deduction_configs')
    .update({
      name: input.name.trim(),
      effective_from: input.effective_from,
      is_active: input.is_active,
      sss_brackets: input.sss_brackets,
      philhealth_employee_rate: input.philhealth_employee_rate,
      philhealth_min_contribution: input.philhealth_min_contribution,
      philhealth_max_contribution: input.philhealth_max_contribution,
      pagibig_employee_rate: input.pagibig_employee_rate,
      pagibig_min_contribution: input.pagibig_min_contribution,
      pagibig_max_contribution: input.pagibig_max_contribution,
      notes: input.notes?.trim() || null,
      updated_at: now,
    })
    .eq('id', id)
    .select('*')
    .single()
  if (error) throwSupabaseError(error, 'Failed to update deduction config')
  await logAudit({
    action: 'payroll.config.update',
    entityType: 'payroll_deduction_configs',
    entityId: id,
    summary: `Updated payroll deduction config: ${input.name}`,
  })
  return mapConfig(data as Record<string, unknown>)
}

export async function listCashAdvances(status?: CashAdvanceRow['status']): Promise<CashAdvanceRow[]> {
  let query = supabase.from('cash_advances').select('*').order('issued_at', { ascending: false })
  if (status) query = query.eq('status', status)
  const { data, error } = await query
  if (error) throwSupabaseError(error, 'Failed to load cash advances')

  const rows = (data ?? []).map((r) => mapCashAdvance(r as Record<string, unknown>))
  const driverIds = [...new Set(rows.map((r) => r.driver_id))]
  if (!driverIds.length) return rows

  const { data: drivers } = await supabase
    .from('drivers')
    .select('id, full_name, email')
    .in('id', driverIds)
  const driverMap = new Map(
    (drivers ?? []).map((d) => [
      String(d.id),
      { full_name: String(d.full_name ?? ''), email: String(d.email ?? '') },
    ]),
  )

  return rows.map((r) => {
    const d = driverMap.get(r.driver_id)
    return {
      ...r,
      driver_name: d?.full_name || 'Driver',
      driver_email: d?.email || '',
    }
  })
}

export async function createCashAdvance(input: {
  driver_id: string
  amount: number
  reason?: string
}): Promise<CashAdvanceRow> {
  if (input.amount <= 0) throw new Error('Amount must be greater than zero')
  const {
    data: { user },
  } = await supabase.auth.getUser()
  const now = new Date().toISOString()
  const { data, error } = await supabase
    .from('cash_advances')
    .insert({
      driver_id: input.driver_id,
      amount: input.amount,
      balance_remaining: input.amount,
      reason: input.reason?.trim() || null,
      status: 'open',
      issued_at: now,
      issued_by: user?.id ?? null,
      created_at: now,
      updated_at: now,
    })
    .select('*')
    .single()
  if (error) throwSupabaseError(error, 'Failed to create cash advance')
  await logAudit({
    action: 'payroll.cash_advance.create',
    entityType: 'cash_advances',
    entityId: String(data.id),
    summary: `Cash advance ₱${input.amount} for driver`,
    metadata: { driver_id: input.driver_id, amount: input.amount },
  })
  return mapCashAdvance(data as Record<string, unknown>)
}

export async function cancelCashAdvance(id: string): Promise<void> {
  const now = new Date().toISOString()
  const { error } = await supabase
    .from('cash_advances')
    .update({ status: 'cancelled', balance_remaining: 0, updated_at: now })
    .eq('id', id)
    .eq('status', 'open')
  if (error) throwSupabaseError(error, 'Failed to cancel cash advance')
  await logAudit({
    action: 'payroll.cash_advance.cancel',
    entityType: 'cash_advances',
    entityId: id,
    summary: 'Cancelled open cash advance',
  })
}

async function openCashAdvanceBalance(driverId: string): Promise<number> {
  const { data, error } = await supabase
    .from('cash_advances')
    .select('balance_remaining')
    .eq('driver_id', driverId)
    .eq('status', 'open')
  if (error) throwSupabaseError(error, 'Failed to load cash advances')
  return (data ?? []).reduce((s, r) => s + Number(r.balance_remaining ?? 0), 0)
}

async function countShiftDays(driverId: string, periodStart: string, periodEnd: string): Promise<number> {
  const { data, error } = await supabase
    .from('driver_attendance')
    .select('clock_in')
    .eq('driver_id', driverId)
    .gte('clock_in', periodStartIso(periodStart))
    .lte('clock_in', periodEndIso(periodEnd))
  if (error) throwSupabaseError(error, 'Failed to load attendance')

  const days = new Set<string>()
  for (const row of data ?? []) {
    const d = new Date(String(row.clock_in))
    days.add(d.toISOString().slice(0, 10))
  }
  return days.size
}

async function fetchTripTotals(
  driverId: string,
  periodStart: string,
  periodEnd: string,
): Promise<{ trip_count: number; total_fares: number }> {
  const { data, error } = await supabase
    .from('trips')
    .select('fare, completed_at, created_at')
    .eq('driver_id', driverId)
    .eq('status', 'completed')
    .gte('completed_at', periodStartIso(periodStart))
    .lte('completed_at', periodEndIso(periodEnd))
  if (error) throwSupabaseError(error, 'Failed to load trips')

  const trips = data ?? []
  const total_fares = trips.reduce((s, t) => s + Number(t.fare ?? 0), 0)
  return { trip_count: trips.length, total_fares }
}

async function fetchDriverBoundaryRate(driverId: string): Promise<{ boundary_rate: number; vehicle_id: string | null }> {
  const { data: vehicle, error } = await supabase
    .from('vehicles')
    .select('id, boundary_fee')
    .eq('assigned_driver_id', driverId)
    .maybeSingle()
  if (error) throwSupabaseError(error, 'Failed to load assigned vehicle')
  if (!vehicle) return { boundary_rate: 0, vehicle_id: null }
  return {
    boundary_rate: Number(vehicle.boundary_fee ?? 0),
    vehicle_id: String(vehicle.id),
  }
}

export async function previewPayroll(input: {
  driver_id: string
  period_start: string
  period_end: string
  other_deductions?: number
}): Promise<PayrollPreview> {
  const config = await fetchActiveDeductionConfig()
  if (!config) throw new Error('No active payroll deduction config. Add one in Payroll → Settings.')

  const [{ trip_count, total_fares }, shift_days, { boundary_rate, vehicle_id }, openBalance] =
    await Promise.all([
      fetchTripTotals(input.driver_id, input.period_start, input.period_end),
      countShiftDays(input.driver_id, input.period_start, input.period_end),
      fetchDriverBoundaryRate(input.driver_id),
      openCashAdvanceBalance(input.driver_id),
    ])

  const amounts = computePayrollAmounts({
    totalFares: total_fares,
    shiftDays: shift_days,
    boundaryRate: boundary_rate,
    openCashAdvanceBalance: openBalance,
    otherDeductions: input.other_deductions ?? 0,
    config,
  })

  return {
    driver_id: input.driver_id,
    period_start: input.period_start,
    period_end: input.period_end,
    trip_count,
    total_fares,
    shift_days,
    boundary_rate,
    vehicle_id,
    deduction_config_id: config.id,
    notes: null,
    other_deductions: input.other_deductions ?? 0,
    open_cash_advance_balance: openBalance,
    ...amounts,
  }
}

export async function listPayrollRecords(filters?: {
  driver_id?: string
  period_start?: string
  period_end?: string
  status?: PayrollRecordRow['status']
}): Promise<PayrollRecordRow[]> {
  let query = supabase.from('payroll_records').select('*').order('period_end', { ascending: false })
  if (filters?.driver_id) query = query.eq('driver_id', filters.driver_id)
  if (filters?.period_start) query = query.gte('period_start', filters.period_start)
  if (filters?.period_end) query = query.lte('period_end', filters.period_end)
  if (filters?.status) query = query.eq('status', filters.status)

  const { data, error } = await query
  if (error) throwSupabaseError(error, 'Failed to load payroll records')

  const rows = (data ?? []).map((r) => mapPayrollRecord(r as Record<string, unknown>))
  const driverIds = [...new Set(rows.map((r) => r.driver_id))]
  if (!driverIds.length) return rows

  const { data: drivers } = await supabase
    .from('drivers')
    .select('id, full_name, email')
    .in('id', driverIds)
  const driverMap = new Map(
    (drivers ?? []).map((d) => [
      String(d.id),
      { full_name: String(d.full_name ?? ''), email: String(d.email ?? '') },
    ]),
  )

  return rows.map((r) => {
    const d = driverMap.get(r.driver_id)
    return {
      ...r,
      driver_name: d?.full_name || 'Driver',
      driver_email: d?.email || '',
    }
  })
}

export async function savePayrollDraft(preview: PayrollPreview): Promise<PayrollRecordRow> {
  const {
    data: { user },
  } = await supabase.auth.getUser()
  const now = new Date().toISOString()
  const payload = {
    driver_id: preview.driver_id,
    period_start: preview.period_start,
    period_end: preview.period_end,
    trip_count: preview.trip_count,
    total_fares: preview.total_fares,
    shift_days: preview.shift_days,
    boundary_rate: preview.boundary_rate,
    boundary_total: preview.boundary_total,
    gross_pay: preview.gross_pay,
    sss_deduction: preview.sss_deduction,
    philhealth_deduction: preview.philhealth_deduction,
    pagibig_deduction: preview.pagibig_deduction,
    cash_advance_deduction: preview.cash_advance_deduction,
    other_deductions: preview.other_deductions,
    net_pay: preview.net_pay,
    vehicle_id: preview.vehicle_id,
    status: 'draft' as const,
    notes: preview.notes,
    deduction_config_id: preview.deduction_config_id,
    created_by: user?.id ?? null,
    updated_at: now,
  }

  const { data, error } = await supabase
    .from('payroll_records')
    .upsert(payload, { onConflict: 'driver_id,period_start,period_end' })
    .select('*')
    .single()
  if (error) throwSupabaseError(error, 'Failed to save payroll draft')
  return mapPayrollRecord(data as Record<string, unknown>)
}

export async function finalizePayrollRecord(id: string): Promise<PayrollRecordRow> {
  const { data: record, error: fetchErr } = await supabase
    .from('payroll_records')
    .select('*')
    .eq('id', id)
    .single()
  if (fetchErr) throwSupabaseError(fetchErr, 'Payroll record not found')
  const row = mapPayrollRecord(record as Record<string, unknown>)
  if (row.status !== 'draft') throw new Error('Only draft records can be finalized')

  const now = new Date().toISOString()
  const { data, error } = await supabase
    .from('payroll_records')
    .update({ status: 'finalized', finalized_at: now, updated_at: now })
    .eq('id', id)
    .select('*')
    .single()
  if (error) throwSupabaseError(error, 'Failed to finalize payroll')

  if (row.cash_advance_deduction > 0) {
    let remaining = row.cash_advance_deduction
    const { data: advances } = await supabase
      .from('cash_advances')
      .select('*')
      .eq('driver_id', row.driver_id)
      .eq('status', 'open')
      .order('issued_at', { ascending: true })
    for (const adv of advances ?? []) {
      if (remaining <= 0) break
      const balance = Number(adv.balance_remaining ?? 0)
      const deduct = Math.min(balance, remaining)
      const newBalance = balance - deduct
      remaining -= deduct
      await supabase
        .from('cash_advances')
        .update({
          balance_remaining: newBalance,
          status: newBalance <= 0 ? 'settled' : 'open',
          settled_at: newBalance <= 0 ? now : null,
          updated_at: now,
        })
        .eq('id', adv.id)
    }
  }

  await logAudit({
    action: 'payroll.finalize',
    entityType: 'payroll_records',
    entityId: id,
    summary: `Finalized payroll for driver (${row.period_start} – ${row.period_end})`,
    metadata: { net_pay: row.net_pay },
  })
  return mapPayrollRecord(data as Record<string, unknown>)
}

export async function markPayrollPaid(id: string): Promise<PayrollRecordRow> {
  const now = new Date().toISOString()
  const { data, error } = await supabase
    .from('payroll_records')
    .update({ status: 'paid', paid_at: now, updated_at: now })
    .eq('id', id)
    .eq('status', 'finalized')
    .select('*')
    .single()
  if (error) throwSupabaseError(error, 'Failed to mark payroll paid')
  await logAudit({
    action: 'payroll.paid',
    entityType: 'payroll_records',
    entityId: id,
    summary: 'Marked payroll as paid',
  })
  return mapPayrollRecord(data as Record<string, unknown>)
}

export function defaultPeriodRange(): { start: string; end: string } {
  const now = new Date()
  const y = now.getFullYear()
  const m = now.getMonth()
  const d = now.getDate()
  if (d <= 15) {
    const start = `${y}-${String(m + 1).padStart(2, '0')}-01`
    const end = `${y}-${String(m + 1).padStart(2, '0')}-15`
    return { start, end }
  }
  const lastDay = new Date(y, m + 1, 0).getDate()
  const start = `${y}-${String(m + 1).padStart(2, '0')}-16`
  const end = `${y}-${String(m + 1).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`
  return { start, end }
}

export async function listApprovedDrivers(): Promise<
  { id: string; full_name: string; email: string }[]
> {
  const { data, error } = await supabase
    .from('drivers')
    .select('id, full_name, email')
    .eq('approval_status', 'approved')
    .order('full_name')
  if (error) throwSupabaseError(error, 'Failed to load drivers')
  return (data ?? []).map((d) => ({
    id: String(d.id),
    full_name: String(d.full_name ?? 'Driver'),
    email: String(d.email ?? ''),
  }))
}
