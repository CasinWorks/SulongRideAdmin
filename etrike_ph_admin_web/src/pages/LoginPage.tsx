import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { operatorEmailDomain, friendlyAuthError } from '../lib/operatorAuth'
import { GoogleMark } from '../components/GoogleMark'
import { adminInputCls, PrimaryButton, ScreenLoader } from '../components/ui/AdminUi'

const googleBtnCls = [
  'flex w-full items-center justify-center gap-3 rounded-xl border border-admin-border',
  'bg-white px-4 py-2.5 text-sm font-medium text-black/80 transition duration-200',
  'hover:bg-admin-bg disabled:opacity-50',
].join(' ')

export function LoginPage() {
  const { signIn, signInWithGoogle, session, loading } = useAuth()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const allowedDomain = operatorEmailDomain()

  useEffect(() => {
    if (!loading && session) navigate('/', { replace: true })
  }, [loading, session, navigate])

  if (loading) return <ScreenLoader />

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await signIn(email.trim(), password)
      navigate('/')
    } catch (err) {
      const raw = err instanceof Error ? err.message : 'Sign in failed'
      setError(friendlyAuthError(raw))
    } finally {
      setBusy(false)
    }
  }

  async function handleGoogle() {
    setBusy(true)
    setError(null)
    try {
      await signInWithGoogle()
    } catch (err) {
      const raw = err instanceof Error ? err.message : 'Google sign-in failed'
      setError(friendlyAuthError(raw))
      setBusy(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-admin-bg p-6">
      <div className="admin-fade-up w-full max-w-md rounded-2xl border border-admin-border bg-white p-8 shadow-sm">
        <p className="text-xs font-medium uppercase tracking-wide text-admin-accent">
          Sulong Ride
        </p>
        <h1 className="mt-1 text-2xl font-semibold">Operator sign in</h1>
        <p className="mt-2 text-sm text-black/55">
          Invite-only: use the link from your admin invite, or sign in after an admin sends you
          one. Driver app accounts cannot use this dashboard.
          {allowedDomain ? (
            <>
              {' '}
              Only <strong>@{allowedDomain}</strong> addresses are accepted.
            </>
          ) : null}
        </p>

        <div className="mt-6 space-y-4">
          <button
            type="button"
            disabled={busy}
            onClick={() => void handleGoogle()}
            className={googleBtnCls}
          >
            <GoogleMark />
            {busy ? 'Redirecting…' : 'Continue with Google'}
          </button>

          <div className="flex items-center gap-3">
            <div className="h-px flex-1 bg-admin-border" />
            <span className="text-xs text-black/40">or use email</span>
            <div className="h-px flex-1 bg-admin-border" />
          </div>
        </div>

        <form onSubmit={(e) => void handleSubmit(e)} className="mt-4 space-y-4">
          <label className="block">
            <span className="text-sm font-medium text-black/70">Email</span>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className={adminInputCls}
            />
          </label>
          <label className="block">
            <span className="text-sm font-medium text-black/70">Password</span>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className={adminInputCls}
            />
          </label>
          {error ? (
            <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>
          ) : null}
          <PrimaryButton type="submit" disabled={busy}>
            {busy ? 'Signing in…' : 'Sign in with email'}
          </PrimaryButton>
        </form>

        <p className="mt-5 text-center text-xs text-black/40">
          Need access? Ask an admin to send you an invite link.
        </p>
      </div>
    </div>
  )
}
