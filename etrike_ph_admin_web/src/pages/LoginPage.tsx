import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { PrimaryButton, LoadingState } from '../components/ui/AdminUi'

export function LoginPage() {
  const { signIn, session, loading } = useAuth()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    if (!loading && session) navigate('/', { replace: true })
  }, [loading, session, navigate])

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-admin-bg">
        <LoadingState />
      </div>
    )
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await signIn(email.trim(), password)
      navigate('/')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sign in failed')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-admin-bg p-6">
      <div className="w-full max-w-md rounded-2xl border border-admin-border bg-white p-8 shadow-sm">
        <p className="text-xs font-medium uppercase tracking-wide text-admin-accent">
          Sulong Ride
        </p>
        <h1 className="mt-1 text-2xl font-semibold">Operator sign in</h1>
        <p className="mt-2 text-sm text-black/55">
          Use your Supabase operator account. You must have a row in{' '}
          <code className="rounded bg-admin-bg px-1">operators</code>.
        </p>
        <form onSubmit={(e) => void handleSubmit(e)} className="mt-6 space-y-4">
          <label className="block">
            <span className="text-sm font-medium text-black/70">Email</span>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="mt-1 w-full rounded-xl border border-admin-border bg-white px-3 py-2.5 text-sm outline-none focus:border-admin-accent"
            />
          </label>
          <label className="block">
            <span className="text-sm font-medium text-black/70">Password</span>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="mt-1 w-full rounded-xl border border-admin-border bg-white px-3 py-2.5 text-sm outline-none focus:border-admin-accent"
            />
          </label>
          {error ? (
            <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>
          ) : null}
          <PrimaryButton type="submit" disabled={busy}>
            {busy ? 'Signing in…' : 'Sign in'}
          </PrimaryButton>
        </form>
      </div>
    </div>
  )
}
