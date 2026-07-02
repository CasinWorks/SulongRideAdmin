import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { operatorEmailDomain, friendlyAuthError } from '../lib/operatorAuth'
import { LoadingState, PrimaryButton } from '../components/ui/AdminUi'

function GoogleMark() {
  return (
    <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden>
      <path
        fill="#FFC107"
        d="M43.611 20.083H42V20H24v8h11.303C33.654 32.657 29.223 36 24 36c-5.522 0-10-4.478-10-10s4.478-10 10-10c2.823 0 5.377 1.172 7.214 3.054l5.657-5.657C33.64 10.11 29.082 8 24 8 12.955 8 4 16.955 4 28s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z"
      />
      <path
        fill="#FF3D00"
        d="M6.306 14.691l6.571 4.819C14.655 16.108 18.961 12 24 12c2.823 0 5.377 1.172 7.214 3.054l5.657-5.657C33.64 10.11 29.082 8 24 8 16.318 8 9.656 12.337 6.306 14.691z"
      />
      <path
        fill="#4CAF50"
        d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238C29.211 35.091 26.715 36 24 36c-5.202 0-9.619-3.317-11.283-7.946l-6.522 5.025C9.505 39.556 16.227 44 24 44z"
      />
      <path
        fill="#1976D2"
        d="M43.611 20.083H42V20H24v8h11.303a12.04 12.04 0 0 1-4.087 5.571l6.19 5.238C42.022 35.026 44 30.138 44 24c0-1.341-.138-2.65-.389-3.917z"
      />
    </svg>
  )
}

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
          Sign in with Google or email. Your account must have a row in{' '}
          <code className="rounded bg-admin-bg px-1">operators</code>.
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
            className="flex w-full items-center justify-center gap-3 rounded-xl border border-admin-border bg-white px-4 py-2.5 text-sm font-medium text-black/80 transition duration-200 hover:bg-admin-bg disabled:opacity-50"
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
            {busy ? 'Signing in…' : 'Sign in with email'}
          </PrimaryButton>
        </form>

        <p className="mt-5 text-center text-xs text-black/40">
          First time with Google? Ask an admin to add your Gmail to{' '}
          <code className="rounded bg-admin-bg px-1">operators</code> in Supabase.
        </p>
      </div>
    </div>
  )
}
