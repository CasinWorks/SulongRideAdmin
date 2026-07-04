import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import {
  cancelCashAdvance,
  createCashAdvance,
  defaultPeriodRange,
  finalizePayrollRecord,
  listApprovedDrivers,
  listCashAdvances,
  listDeductionConfigs,
  listPayrollRecords,
  markPayrollPaid,
  previewPayroll,
  savePayrollDraft,
  updateDeductionConfig,
} from '../services/payroll'
import type {
  CashAdvanceRow,
  PayrollDeductionConfig,
  PayrollPreview,
  PayrollRecordRow,
  SssBracket,
} from '../types/payroll'
import { formatDate, formatPeso, driverDisplayName } from '../lib/format'
import {
  ErrorState,
  GhostButton,
  LoadingState,
  PanelCard,
  PrimaryButton,
  adminInputCls,
  adminSearchInputCls,
} from '../components/ui/adminPageUi'

type Tab = 'records' | 'generate' | 'advances' | 'settings'

function payrollStatusClass(status: PayrollRecordRow['status']): string {
  switch (status) {
    case 'paid':
      return 'bg-green-100 text-green-800'
    case 'finalized':
      return 'bg-blue-100 text-blue-800'
    default:
      return 'bg-amber-100 text-amber-800'
  }
}

function BreakdownTable({ row }: { row: PayrollPreview | PayrollRecordRow }) {
  return (
    <dl className="grid gap-2 text-sm sm:grid-cols-2">
      <div className="flex justify-between gap-4 border-b border-admin-border/60 py-2">
        <dt className="text-black/55">Completed trips</dt>
        <dd className="font-medium">{row.trip_count}</dd>
      </div>
      <div className="flex justify-between gap-4 border-b border-admin-border/60 py-2">
        <dt className="text-black/55">Total fares</dt>
        <dd className="font-medium">{formatPeso(row.total_fares)}</dd>
      </div>
      <div className="flex justify-between gap-4 border-b border-admin-border/60 py-2">
        <dt className="text-black/55">Shift days (attendance)</dt>
        <dd className="font-medium">
          {row.shift_days} × {formatPeso(row.boundary_rate)} boundary
        </dd>
      </div>
      <div className="flex justify-between gap-4 border-b border-admin-border/60 py-2">
        <dt className="text-black/55">Boundary total</dt>
        <dd className="font-medium text-red-700">−{formatPeso(row.boundary_total)}</dd>
      </div>
      <div className="flex justify-between gap-4 border-b border-admin-border/60 py-2 sm:col-span-2">
        <dt className="text-black/55">Gross pay</dt>
        <dd className="font-semibold">{formatPeso(row.gross_pay)}</dd>
      </div>
      <div className="flex justify-between gap-4 border-b border-admin-border/60 py-2">
        <dt className="text-black/55">SSS</dt>
        <dd className="font-medium text-red-700">−{formatPeso(row.sss_deduction)}</dd>
      </div>
      <div className="flex justify-between gap-4 border-b border-admin-border/60 py-2">
        <dt className="text-black/55">PhilHealth</dt>
        <dd className="font-medium text-red-700">−{formatPeso(row.philhealth_deduction)}</dd>
      </div>
      <div className="flex justify-between gap-4 border-b border-admin-border/60 py-2">
        <dt className="text-black/55">Pag-IBIG</dt>
        <dd className="font-medium text-red-700">−{formatPeso(row.pagibig_deduction)}</dd>
      </div>
      {row.other_deductions > 0 ? (
        <div className="flex justify-between gap-4 border-b border-admin-border/60 py-2">
          <dt className="text-black/55">Other deductions</dt>
          <dd className="font-medium text-red-700">−{formatPeso(row.other_deductions)}</dd>
        </div>
      ) : null}
      <div className="flex justify-between gap-4 border-b border-admin-border/60 py-2">
        <dt className="text-black/55">Cash advance</dt>
        <dd className="font-medium text-red-700">−{formatPeso(row.cash_advance_deduction)}</dd>
      </div>
      <div className="flex justify-between gap-4 py-2 sm:col-span-2">
        <dt className="text-black/87 font-medium">Net pay</dt>
        <dd className="text-lg font-semibold text-admin-accent">{formatPeso(row.net_pay)}</dd>
      </div>
    </dl>
  )
}

export function PayrollPage() {
  const { canWritePayroll } = useAuth()
  const [tab, setTab] = useState<Tab>('records')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [records, setRecords] = useState<PayrollRecordRow[]>([])
  const [advances, setAdvances] = useState<CashAdvanceRow[]>([])
  const [drivers, setDrivers] = useState<{ id: string; full_name: string; email: string }[]>([])
  const [configs, setConfigs] = useState<PayrollDeductionConfig[]>([])
  const [recordQuery, setRecordQuery] = useState('')

  const defaultRange = defaultPeriodRange()
  const [genDriverId, setGenDriverId] = useState('')
  const [periodStart, setPeriodStart] = useState(defaultRange.start)
  const [periodEnd, setPeriodEnd] = useState(defaultRange.end)
  const [otherDeductions, setOtherDeductions] = useState(0)
  const [preview, setPreview] = useState<PayrollPreview | null>(null)
  const [genBusy, setGenBusy] = useState(false)

  const [advDriverId, setAdvDriverId] = useState('')
  const [advAmount, setAdvAmount] = useState('')
  const [advReason, setAdvReason] = useState('')
  const [advBusy, setAdvBusy] = useState(false)

  const [settingsForm, setSettingsForm] = useState<PayrollDeductionConfig | null>(null)
  const [settingsBusy, setSettingsBusy] = useState(false)
  const [sssJson, setSssJson] = useState('')

  function loadBase() {
    setLoading(true)
    setError(null)
    Promise.all([
      listPayrollRecords(),
      listCashAdvances(),
      listApprovedDrivers(),
      listDeductionConfigs(),
    ])
      .then(([recs, adv, drvs, cfgs]) => {
        setRecords(recs)
        setAdvances(adv)
        setDrivers(drvs)
        setConfigs(cfgs)
        if (!genDriverId && drvs[0]) setGenDriverId(drvs[0].id)
        if (!advDriverId && drvs[0]) setAdvDriverId(drvs[0].id)
        const active = cfgs.find((c) => c.is_active) ?? cfgs[0] ?? null
        if (active) {
          setSettingsForm(active)
          setSssJson(JSON.stringify(active.sss_brackets, null, 2))
        }
      })
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load payroll'))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    loadBase()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const filteredRecords = useMemo(() => {
    const q = recordQuery.trim().toLowerCase()
    if (!q) return records
    return records.filter(
      (r) =>
        (r.driver_name ?? '').toLowerCase().includes(q) ||
        (r.driver_email ?? '').toLowerCase().includes(q) ||
        r.driver_id.toLowerCase().includes(q),
    )
  }, [records, recordQuery])

  async function handlePreview() {
    if (!genDriverId) return
    setGenBusy(true)
    setError(null)
    try {
      const p = await previewPayroll({
        driver_id: genDriverId,
        period_start: periodStart,
        period_end: periodEnd,
        other_deductions: otherDeductions,
      })
      setPreview(p)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Preview failed')
    } finally {
      setGenBusy(false)
    }
  }

  async function handleSaveDraft() {
    if (!preview) return
    setGenBusy(true)
    try {
      await savePayrollDraft(preview)
      setPreview(null)
      loadBase()
      setTab('records')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed')
    } finally {
      setGenBusy(false)
    }
  }

  async function handleFinalize(id: string) {
    try {
      await finalizePayrollRecord(id)
      loadBase()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Finalize failed')
    }
  }

  async function handleMarkPaid(id: string) {
    try {
      await markPayrollPaid(id)
      loadBase()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Update failed')
    }
  }

  async function handleCreateAdvance(e: React.FormEvent) {
    e.preventDefault()
    const amount = Number(advAmount)
    if (!advDriverId || !amount) return
    setAdvBusy(true)
    try {
      await createCashAdvance({ driver_id: advDriverId, amount, reason: advReason })
      setAdvAmount('')
      setAdvReason('')
      loadBase()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create advance')
    } finally {
      setAdvBusy(false)
    }
  }

  async function handleSaveSettings(e: React.FormEvent) {
    e.preventDefault()
    if (!settingsForm) return
    let brackets: SssBracket[]
    try {
      brackets = JSON.parse(sssJson) as SssBracket[]
      if (!Array.isArray(brackets)) throw new Error('SSS brackets must be a JSON array')
    } catch {
      setError('Invalid SSS brackets JSON')
      return
    }
    setSettingsBusy(true)
    try {
      await updateDeductionConfig(settingsForm.id, {
        name: settingsForm.name,
        effective_from: settingsForm.effective_from,
        is_active: settingsForm.is_active,
        sss_brackets: brackets,
        philhealth_employee_rate: settingsForm.philhealth_employee_rate,
        philhealth_min_contribution: settingsForm.philhealth_min_contribution,
        philhealth_max_contribution: settingsForm.philhealth_max_contribution,
        pagibig_employee_rate: settingsForm.pagibig_employee_rate,
        pagibig_min_contribution: settingsForm.pagibig_min_contribution,
        pagibig_max_contribution: settingsForm.pagibig_max_contribution,
        notes: settingsForm.notes ?? undefined,
      })
      loadBase()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save settings')
    } finally {
      setSettingsBusy(false)
    }
  }

  const tabs: { id: Tab; label: string }[] = [
    { id: 'records', label: 'Payroll records' },
    { id: 'generate', label: 'Generate' },
    { id: 'advances', label: 'Cash advances' },
    { id: 'settings', label: 'Deduction settings' },
  ]

  if (loading) return <LoadingState />

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold">Payroll</h2>
        <p className="mt-1 text-sm text-black/55">
          Gross = total fares − boundary (per attendance day × assigned unit rate). Statutory
          deductions use admin-configurable rates. Open cash advances auto-deduct on finalize.
        </p>
      </div>

      {error ? <ErrorState message={error} /> : null}

      <div className="flex flex-wrap gap-2">
        {tabs.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => {
              setError(null)
              setTab(t.id)
            }}
            className={`rounded-xl border px-3 py-2 text-sm font-medium ${
              tab === t.id
                ? 'border-admin-accent bg-admin-accent/10 text-black/87'
                : 'border-admin-border bg-white text-black/60 hover:bg-admin-bg'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {tab === 'records' ? (
        <PanelCard
          title="Saved payroll"
          action={
            <input
              className={adminSearchInputCls}
              placeholder="Search driver…"
              value={recordQuery}
              onChange={(e) => setRecordQuery(e.target.value)}
            />
          }
        >
          {filteredRecords.length === 0 ? (
            <p className="text-sm text-black/50">No payroll records yet. Generate one for a driver.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[720px] text-left text-sm">
                <thead>
                  <tr className="border-b border-admin-border text-black/50">
                    <th className="py-2 pr-4 font-medium">Driver</th>
                    <th className="py-2 pr-4 font-medium">Period</th>
                    <th className="py-2 pr-4 font-medium">Gross</th>
                    <th className="py-2 pr-4 font-medium">Net</th>
                    <th className="py-2 pr-4 font-medium">Status</th>
                    <th className="py-2 font-medium">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredRecords.map((r) => (
                    <tr key={r.id} className="border-b border-admin-border/60">
                      <td className="py-3 pr-4">
                        <Link
                          to={`/drivers/${r.driver_id}`}
                          className="font-medium text-admin-accent hover:underline"
                        >
                          {driverDisplayName({ full_name: r.driver_name, email: r.driver_email })}
                        </Link>
                      </td>
                      <td className="py-3 pr-4 text-black/70">
                        {formatDate(r.period_start)} – {formatDate(r.period_end)}
                      </td>
                      <td className="py-3 pr-4">{formatPeso(r.gross_pay)}</td>
                      <td className="py-3 pr-4 font-medium">{formatPeso(r.net_pay)}</td>
                      <td className="py-3 pr-4">
                        <span
                          className={`rounded-full px-2.5 py-0.5 text-xs font-medium capitalize ${payrollStatusClass(r.status)}`}
                        >
                          {r.status}
                        </span>
                      </td>
                      <td className="py-3">
                        {canWritePayroll ? (
                        <div className="flex flex-wrap gap-2">
                          {r.status === 'draft' ? (
                            <GhostButton onClick={() => void handleFinalize(r.id)}>
                              Finalize
                            </GhostButton>
                          ) : null}
                          {r.status === 'finalized' ? (
                            <PrimaryButton onClick={() => void handleMarkPaid(r.id)}>
                              Mark paid
                            </PrimaryButton>
                          ) : null}
                        </div>
                        ) : (
                          <span className="text-xs text-black/45">—</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </PanelCard>
      ) : null}

      {tab === 'generate' ? (
        <div className="grid gap-6 lg:grid-cols-2">
          <PanelCard title="Compute payroll">
            <fieldset disabled={!canWritePayroll} className="min-w-0 border-0 p-0">
            <div className="space-y-4">
              <label className="block text-sm">
                <span className="text-black/55">Driver</span>
                <select
                  className={adminInputCls}
                  value={genDriverId}
                  onChange={(e) => setGenDriverId(e.target.value)}
                >
                  {drivers.map((d) => (
                    <option key={d.id} value={d.id}>
                      {driverDisplayName(d)}
                    </option>
                  ))}
                </select>
              </label>
              <div className="grid gap-4 sm:grid-cols-2">
                <label className="block text-sm">
                  <span className="text-black/55">Period start</span>
                  <input
                    type="date"
                    className={adminInputCls}
                    value={periodStart}
                    onChange={(e) => setPeriodStart(e.target.value)}
                  />
                </label>
                <label className="block text-sm">
                  <span className="text-black/55">Period end</span>
                  <input
                    type="date"
                    className={adminInputCls}
                    value={periodEnd}
                    onChange={(e) => setPeriodEnd(e.target.value)}
                  />
                </label>
              </div>
              <label className="block text-sm">
                <span className="text-black/55">Other deductions (₱)</span>
                <input
                  type="number"
                  min={0}
                  step={0.01}
                  className={adminInputCls}
                  value={otherDeductions}
                  onChange={(e) => setOtherDeductions(Number(e.target.value))}
                />
              </label>
              <PrimaryButton disabled={genBusy || !genDriverId} onClick={() => void handlePreview()}>
                {genBusy ? 'Computing…' : 'Preview breakdown'}
              </PrimaryButton>
            </div>
            </fieldset>
          </PanelCard>

          {preview ? (
            <PanelCard
              title="Preview"
              action={
                canWritePayroll ? (
                <PrimaryButton disabled={genBusy} onClick={() => void handleSaveDraft()}>
                  Save draft
                </PrimaryButton>
                ) : null
              }
            >
              {'open_cash_advance_balance' in preview && preview.open_cash_advance_balance > 0 ? (
                <p className="mb-3 text-xs text-amber-800">
                  Open cash advance balance: {formatPeso(preview.open_cash_advance_balance)} (deducted
                  up to net pay on finalize)
                </p>
              ) : null}
              <BreakdownTable row={preview} />
            </PanelCard>
          ) : (
            <PanelCard title="Preview">
              <p className="text-sm text-black/50">
                Select a driver and period, then preview. Uses completed trips, attendance days, assigned
                unit boundary fee, and active deduction config.
              </p>
            </PanelCard>
          )}
        </div>
      ) : null}

      {tab === 'advances' ? (
        <div className="grid gap-6 lg:grid-cols-2">
          <PanelCard title="Issue cash advance">
            <fieldset disabled={!canWritePayroll} className="min-w-0 border-0 p-0">
            <form className="space-y-4" onSubmit={(e) => void handleCreateAdvance(e)}>
              <label className="block text-sm">
                <span className="text-black/55">Driver</span>
                <select
                  className={adminInputCls}
                  value={advDriverId}
                  onChange={(e) => setAdvDriverId(e.target.value)}
                >
                  {drivers.map((d) => (
                    <option key={d.id} value={d.id}>
                      {driverDisplayName(d)}
                    </option>
                  ))}
                </select>
              </label>
              <label className="block text-sm">
                <span className="text-black/55">Amount (₱)</span>
                <input
                  type="number"
                  min={1}
                  step={0.01}
                  required
                  className={adminInputCls}
                  value={advAmount}
                  onChange={(e) => setAdvAmount(e.target.value)}
                />
              </label>
              <label className="block text-sm">
                <span className="text-black/55">Reason (optional)</span>
                <input
                  className={adminInputCls}
                  value={advReason}
                  onChange={(e) => setAdvReason(e.target.value)}
                />
              </label>
              <PrimaryButton type="submit" disabled={advBusy}>
                {advBusy ? 'Saving…' : 'Issue advance'}
              </PrimaryButton>
            </form>
            </fieldset>
          </PanelCard>

          <PanelCard title="Open & recent advances">
            {advances.length === 0 ? (
              <p className="text-sm text-black/50">No cash advances recorded.</p>
            ) : (
              <ul className="divide-y divide-admin-border/60">
                {advances.map((a) => (
                  <li key={a.id} className="flex flex-wrap items-center justify-between gap-2 py-3">
                    <div>
                      <p className="font-medium">{driverDisplayName({ full_name: a.driver_name, email: a.driver_email })}</p>
                      <p className="text-xs text-black/50">
                        {formatPeso(a.amount)} issued · balance {formatPeso(a.balance_remaining)} ·{' '}
                        {a.status}
                      </p>
                    </div>
                    {a.status === 'open' && canWritePayroll ? (
                      <GhostButton onClick={() => void cancelCashAdvance(a.id).then(loadBase)}>
                        Cancel
                      </GhostButton>
                    ) : null}
                  </li>
                ))}
              </ul>
            )}
          </PanelCard>
        </div>
      ) : null}

      {tab === 'settings' && settingsForm ? (
        <PanelCard title="Statutory deduction config">
          <fieldset disabled={!canWritePayroll} className="min-w-0 border-0 p-0">
          <form className="space-y-4" onSubmit={(e) => void handleSaveSettings(e)}>
            <p className="text-sm text-black/55">
              Active config: <strong>{settingsForm.name}</strong>. SSS uses monthly salary credit
              brackets (semi-monthly gross × 2). Update when government circulars change.
            </p>
            <div className="grid gap-4 sm:grid-cols-2">
              <label className="block text-sm">
                <span className="text-black/55">Config name</span>
                <input
                  className={adminInputCls}
                  value={settingsForm.name}
                  onChange={(e) => setSettingsForm({ ...settingsForm, name: e.target.value })}
                />
              </label>
              <label className="block text-sm">
                <span className="text-black/55">Effective from</span>
                <input
                  type="date"
                  className={adminInputCls}
                  value={settingsForm.effective_from.slice(0, 10)}
                  onChange={(e) =>
                    setSettingsForm({ ...settingsForm, effective_from: e.target.value })
                  }
                />
              </label>
            </div>
            <div className="grid gap-4 sm:grid-cols-3">
              <label className="block text-sm">
                <span className="text-black/55">PhilHealth employee rate</span>
                <input
                  type="number"
                  step={0.0001}
                  className={adminInputCls}
                  value={settingsForm.philhealth_employee_rate}
                  onChange={(e) =>
                    setSettingsForm({
                      ...settingsForm,
                      philhealth_employee_rate: Number(e.target.value),
                    })
                  }
                />
              </label>
              <label className="block text-sm">
                <span className="text-black/55">PhilHealth min ₱</span>
                <input
                  type="number"
                  className={adminInputCls}
                  value={settingsForm.philhealth_min_contribution}
                  onChange={(e) =>
                    setSettingsForm({
                      ...settingsForm,
                      philhealth_min_contribution: Number(e.target.value),
                    })
                  }
                />
              </label>
              <label className="block text-sm">
                <span className="text-black/55">PhilHealth max ₱</span>
                <input
                  type="number"
                  className={adminInputCls}
                  value={settingsForm.philhealth_max_contribution}
                  onChange={(e) =>
                    setSettingsForm({
                      ...settingsForm,
                      philhealth_max_contribution: Number(e.target.value),
                    })
                  }
                />
              </label>
            </div>
            <div className="grid gap-4 sm:grid-cols-3">
              <label className="block text-sm">
                <span className="text-black/55">Pag-IBIG employee rate</span>
                <input
                  type="number"
                  step={0.0001}
                  className={adminInputCls}
                  value={settingsForm.pagibig_employee_rate}
                  onChange={(e) =>
                    setSettingsForm({
                      ...settingsForm,
                      pagibig_employee_rate: Number(e.target.value),
                    })
                  }
                />
              </label>
              <label className="block text-sm">
                <span className="text-black/55">Pag-IBIG min ₱</span>
                <input
                  type="number"
                  className={adminInputCls}
                  value={settingsForm.pagibig_min_contribution}
                  onChange={(e) =>
                    setSettingsForm({
                      ...settingsForm,
                      pagibig_min_contribution: Number(e.target.value),
                    })
                  }
                />
              </label>
              <label className="block text-sm">
                <span className="text-black/55">Pag-IBIG max ₱</span>
                <input
                  type="number"
                  className={adminInputCls}
                  value={settingsForm.pagibig_max_contribution}
                  onChange={(e) =>
                    setSettingsForm({
                      ...settingsForm,
                      pagibig_max_contribution: Number(e.target.value),
                    })
                  }
                />
              </label>
            </div>
            <label className="block text-sm">
              <span className="text-black/55">SSS brackets (JSON array)</span>
              <textarea
                className={`${adminInputCls} min-h-[200px] font-mono text-xs`}
                value={sssJson}
                onChange={(e) => setSssJson(e.target.value)}
              />
            </label>
            {configs.length > 1 ? (
              <p className="text-xs text-black/45">
                {configs.length} config versions on file — editing the active one above.
              </p>
            ) : null}
            <PrimaryButton type="submit" disabled={settingsBusy}>
              {settingsBusy ? 'Saving…' : 'Save deduction settings'}
            </PrimaryButton>
          </form>
          </fieldset>
        </PanelCard>
      ) : null}

      {tab === 'settings' && !settingsForm ? (
        <PanelCard title="Deduction settings">
          <p className="text-sm text-black/55">
            No deduction config found. Run <code>fix_payroll.sql</code> in Supabase SQL Editor first.
          </p>
        </PanelCard>
      ) : null}
    </div>
  )
}
