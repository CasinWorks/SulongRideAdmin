export type SssBracket = {
  msc_min: number
  msc_max: number
  employee: number
}

export type PayrollDeductionConfig = {
  id: string
  name: string
  effective_from: string
  is_active: boolean
  sss_brackets: SssBracket[]
  philhealth_employee_rate: number
  philhealth_min_contribution: number
  philhealth_max_contribution: number
  pagibig_employee_rate: number
  pagibig_min_contribution: number
  pagibig_max_contribution: number
  notes: string | null
  created_at: string
  updated_at: string
}

export type CashAdvanceRow = {
  id: string
  driver_id: string
  amount: number
  balance_remaining: number
  reason: string | null
  status: 'open' | 'settled' | 'cancelled'
  issued_at: string
  issued_by: string | null
  settled_at: string | null
  created_at: string
  updated_at: string
  driver_name?: string
  driver_email?: string
}

export type PayrollRecordRow = {
  id: string
  driver_id: string
  period_start: string
  period_end: string
  trip_count: number
  total_fares: number
  shift_days: number
  boundary_rate: number
  boundary_total: number
  gross_pay: number
  sss_deduction: number
  philhealth_deduction: number
  pagibig_deduction: number
  cash_advance_deduction: number
  other_deductions: number
  net_pay: number
  vehicle_id: string | null
  status: 'draft' | 'finalized' | 'paid'
  notes: string | null
  deduction_config_id: string | null
  created_by: string | null
  finalized_at: string | null
  paid_at: string | null
  created_at: string
  updated_at: string
  driver_name?: string
  driver_email?: string
}

export type PayrollPreview = Omit<
  PayrollRecordRow,
  'id' | 'status' | 'created_by' | 'finalized_at' | 'paid_at' | 'created_at' | 'updated_at'
> & {
  open_cash_advance_balance: number
}

export type PayrollDeductionConfigInput = {
  name: string
  effective_from: string
  is_active: boolean
  sss_brackets: SssBracket[]
  philhealth_employee_rate: number
  philhealth_min_contribution: number
  philhealth_max_contribution: number
  pagibig_employee_rate: number
  pagibig_min_contribution: number
  pagibig_max_contribution: number
  notes?: string
}
