import { useEffect, useState } from 'react'
import { fetchActiveFare, updateActiveFare } from '../services/admin'
import type { FareConfig } from '../types'
import { ErrorState, LoadingState, PanelCard, PrimaryButton } from '../components/ui/AdminUi'

export function FarePage() {
  const [fare, setFare] = useState<FareConfig | null>(null)
  const [base, setBase] = useState('')
  const [perKm, setPerKm] = useState('')
  const [minimum, setMinimum] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    fetchActiveFare()
      .then((f) => {
        setFare(f)
        if (f) {
          setBase(String(f.base_fare))
          setPerKm(String(f.per_km_rate))
          setMinimum(String(f.minimum_fare))
        }
      })
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load fare'))
      .finally(() => setLoading(false))
  }, [])

  async function handleSave() {
    if (!fare) return
    setSaving(true)
    setError(null)
    setMessage(null)
    try {
      await updateActiveFare({
        id: fare.id,
        baseFare: Number(base),
        perKmRate: Number(perKm),
        minimumFare: Number(minimum),
      })
      setMessage('Fare updated')
      const refreshed = await fetchActiveFare()
      setFare(refreshed)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed')
    } finally {
      setSaving(false)
    }
  }

  if (loading) return <LoadingState />
  if (!fare) {
    return (
      <ErrorState message="No active fare_config row. Run supabase/fix_carmona_pilot.sql in Supabase SQL Editor." />
    )
  }

  return (
    <PanelCard title="Active fare (Carmona pilot)">
      <p className="mb-6 text-sm text-black/55">
        Changes apply to new rider bookings immediately via{' '}
        <code className="rounded bg-admin-bg px-1">fare_config</code>.
      </p>
      <div className="grid max-w-md gap-4">
        <label className="block">
          <span className="text-sm font-medium">Base fare (₱)</span>
          <input
            type="number"
            value={base}
            onChange={(e) => setBase(e.target.value)}
            className="mt-1 w-full rounded-xl border border-admin-border px-3 py-2.5 text-sm"
          />
        </label>
        <label className="block">
          <span className="text-sm font-medium">Per km rate (₱)</span>
          <input
            type="number"
            value={perKm}
            onChange={(e) => setPerKm(e.target.value)}
            className="mt-1 w-full rounded-xl border border-admin-border px-3 py-2.5 text-sm"
          />
        </label>
        <label className="block">
          <span className="text-sm font-medium">Minimum fare (₱)</span>
          <input
            type="number"
            value={minimum}
            onChange={(e) => setMinimum(e.target.value)}
            className="mt-1 w-full rounded-xl border border-admin-border px-3 py-2.5 text-sm"
          />
        </label>
        <PrimaryButton disabled={saving} onClick={() => void handleSave()}>
          {saving ? 'Saving…' : 'Save fare'}
        </PrimaryButton>
        {message ? <p className="text-sm text-green-700">{message}</p> : null}
        {error ? <p className="text-sm text-red-700">{error}</p> : null}
      </div>
    </PanelCard>
  )
}
