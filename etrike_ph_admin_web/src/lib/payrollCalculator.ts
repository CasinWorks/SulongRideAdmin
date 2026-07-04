import type { PayrollDeductionConfig, SssBracket } from '../types/payroll'

/** Monthly salary credit basis for bracket lookup (semi-monthly gross × 2). */
export function monthlySalaryBasis(periodGross: number): number {
  return Math.max(0, periodGross * 2)
}

export function computeSssEmployee(config: PayrollDeductionConfig, periodGross: number): number {
  const msc = monthlySalaryBasis(periodGross)
  const brackets = config.sss_brackets ?? []
  if (brackets.length === 0) return 0
  const bracket =
    brackets.find((b) => msc >= b.msc_min && msc <= b.msc_max) ?? brackets[brackets.length - 1]
  return bracket?.employee ?? 0
}

export function computePhilHealthEmployee(
  config: PayrollDeductionConfig,
  periodGross: number,
): number {
  const monthly = monthlySalaryBasis(periodGross)
  const raw = monthly * config.philhealth_employee_rate
  return Math.min(
    config.philhealth_max_contribution,
    Math.max(config.philhealth_min_contribution, raw),
  )
}

export function computePagIbigEmployee(config: PayrollDeductionConfig, periodGross: number): number {
  const monthly = monthlySalaryBasis(periodGross)
  const raw = monthly * config.pagibig_employee_rate
  return Math.min(
    config.pagibig_max_contribution,
    Math.max(config.pagibig_min_contribution, raw),
  )
}

export function computePayrollAmounts(input: {
  totalFares: number
  shiftDays: number
  boundaryRate: number
  openCashAdvanceBalance: number
  otherDeductions?: number
  config: PayrollDeductionConfig
}): {
  boundary_total: number
  gross_pay: number
  sss_deduction: number
  philhealth_deduction: number
  pagibig_deduction: number
  cash_advance_deduction: number
  net_pay: number
} {
  const boundary_total = Math.max(0, input.shiftDays * input.boundaryRate)
  const gross_pay = Math.max(0, input.totalFares - boundary_total)

  const sss_deduction = computeSssEmployee(input.config, gross_pay)
  const philhealth_deduction = computePhilHealthEmployee(input.config, gross_pay)
  const pagibig_deduction = computePagIbigEmployee(input.config, gross_pay)

  const afterStatutory =
    gross_pay - sss_deduction - philhealth_deduction - pagibig_deduction - (input.otherDeductions ?? 0)

  const cash_advance_deduction = Math.min(
    Math.max(0, input.openCashAdvanceBalance),
    Math.max(0, afterStatutory),
  )

  const net_pay = Math.max(0, afterStatutory - cash_advance_deduction)

  return {
    boundary_total,
    gross_pay,
    sss_deduction,
    philhealth_deduction,
    pagibig_deduction,
    cash_advance_deduction,
    net_pay,
  }
}

export function parseSssBrackets(raw: unknown): SssBracket[] {
  if (!Array.isArray(raw)) return []
  return raw
    .map((b) => {
      const row = b as Record<string, unknown>
      return {
        msc_min: Number(row.msc_min ?? 0),
        msc_max: Number(row.msc_max ?? 0),
        employee: Number(row.employee ?? 0),
      }
    })
    .filter((b) => b.msc_max >= b.msc_min)
}
