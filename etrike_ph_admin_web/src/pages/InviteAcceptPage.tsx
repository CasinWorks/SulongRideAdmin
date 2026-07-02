import { useCallback, useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { operatorEmailDomain, friendlyAuthError } from '../lib/operatorAuth'
import { GoogleMark } from '../components/GoogleMark'
import {
  adminInputCls,
  GhostButton,
  PrimaryButton,
  ScreenLoader,
} from '../components/ui/AdminUi'
import {
  claimOperatorInvite,
  fetchOperatorInviteByToken,
} from '../services/invites'
import type { OperatorInvitePreview } from '../types'

const googleBtnCls = [
  'flex w-full items-center justify-center gap-3 rounded-xl border border-admin-border',
  'bg-white px-4 py-2.5 text-sm font-medium text-black/80 transition duration-200',
  'hover:bg-admin-bg disabled:opacity-50',
].join(' ')

function roleLabel(role: string): string {
  return role.replace('_', ' ')
}

export function InviteAcceptPage() {
  const { token = '' } = useParams()
  const navigate = useNavigate()
  const {
    session,
    loading: authLoading,
    signIn,
    signInWithGoogle,
    refreshOperator,
    isDriverAccount,
    operator,
    emailAllowed,
  } = useAuth()

  const [invite, setInvite] = useState<OperatorInvitePreview | null>(null)
  const [inviteLoading, setInviteLoading] = useState(true)
  const [inviteError, setInviteError] = useState<string | null>(null)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [claiming, setClaiming] = useState(false)
  const allowedDomain = operatorEmailDomain()

  useEffect(() => {
    if (!token) {
      setInviteError('Invalid invite link')
      setInviteLoading(false)
      return
    }

    setInviteLoading(true)
    fetchOperatorInviteByToken(token)
      .then((row) => {
        if (!row) setInviteError('This invite link is invalid or has been removed.')
        else {
          setInvite(row)
          setEmail(row.email)
        }
      })
      .catch((e) => {
        setInviteError(e instanceof Error ? e.message : 'Could not load invite')
      })
      .finally(() => setInviteLoading(false))
  }, [token])

  const tryClaim = useCallback(async () => {
    if (!token || !session?.user) return
    setClaiming(true)
    setError(null)
    try {
      await claimOperatorInvite(token)
      await refreshOperator()
      navigate('/', { replace: true })
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not accept invite')
    } finally {
      setClaiming(false)
    }
  }, [navigate, refreshOperator, session?.user, token])

  useEffect(() => {
    if (authLoading || inviteLoading || !session?.user || !invite) return
    if (invite.status !== 'pending') return
    if (!emailAllowed) return
    if (isDriverAccount) return
    if (operator) {
      navigate('/', { replace: true })
      return
    }
    void tryClaim()
  }, [
    authLoading,
    emailAllowed,
    invite,
    inviteLoading,
    isDriverAccount,
    navigate,
    operator,
    session?.user,
    tryClaim,
  ])

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await signIn(email.trim(), password)
    } catch (err) {
      setError(friendlyAuthError(err instanceof Error ? err.message : 'Sign in failed'))
      setBusy(false)
    }
  }

  async function handleGoogle() {
    setBusy(true)
    setError(null)
    try {
      await signInWithGoogle(`/invite/${token}`)
    } catch (err) {
      setError(friendlyAuthError(err instanceof Error ? err.message : 'Google sign-in failed'))
      setBusy(false)
    }
  }

  if (authLoading || inviteLoading) return <ScreenLoader />

  if (inviteError || !invite) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-admin-bg p-6">
        <div className="w-full max-w-md rounded-2xl border border-admin-border bg-white p-8 text-center shadow-sm">
          <h1 className="text-xl font-semibold">Invite unavailable</h1>
          <p className="mt-3 text-sm text-black/55">{inviteError ?? 'Invite not found.'}</p>
          <Link to="/login" className="mt-6 inline-block text-sm font-medium text-admin-accent">
            Go to sign in
          </Link>
        </div>
      </div>
    )
  }

  if (invite.status === 'revoked') {
    return (
      <InviteStatusCard
        title="Invite revoked"
        body="This invite was cancelled by an administrator. Ask them to send a new link."
      />
    )
  }

  if (invite.status === 'expired') {
    return (
      <InviteStatusCard
        title="Invite expired"
        body="This link has expired. Ask an admin to send a fresh invite."
      />
    )
  }

  if (invite.status === 'accepted') {
    return (
      <InviteStatusCard
        title="Invite already used"
        body={
          invite.accepted_at
            ? `This invite was accepted on ${new Date(invite.accepted_at).toLocaleString()}.`
            : 'This invite has already been accepted.'
        }
        action={
          session ? (
            <PrimaryButton onClick={() => navigate('/')}>Open dashboard</PrimaryButton>
          ) : (
            <Link to="/login">
              <PrimaryButton>Sign in</PrimaryButton>
            </Link>
          )
        }
      />
    )
  }

  if (session && !emailAllowed) {
    return (
      <InviteStatusCard
        title="Email not allowed"
        body={`Sign in with ${invite.email}. This panel only accepts @${allowedDomain ?? 'your organization'} addresses.`}
      />
    )
  }

  if (session && isDriverAccount) {
    return (
      <InviteStatusCard
        title="Driver account not allowed"
        body="Use a separate email for operator access, or ask an admin for help."
      />
    )
  }

  if (claiming || (session && !operator)) {
    return <ScreenLoader label="Accepting invite…" />
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-admin-bg p-6">
      <div className="admin-fade-up w-full max-w-md rounded-2xl border border-admin-border bg-white p-8 shadow-sm">
        <p className="text-xs font-medium uppercase tracking-wide text-admin-accent">
          Sulong Ride
        </p>
        <h1 className="mt-1 text-2xl font-semibold">You&apos;re invited</h1>
        <p className="mt-2 text-sm text-black/55">
          Join the operator dashboard as <strong>{roleLabel(invite.role)}</strong> for{' '}
          <strong>{invite.email}</strong>.
        </p>
        <p className="mt-2 text-xs text-black/45">
          Expires {new Date(invite.expires_at).toLocaleString()}. After sign-in, a super admin
          must approve your access.
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
              readOnly
              value={email}
              className={`${adminInputCls} bg-admin-bg/60`}
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
            {busy ? 'Signing in…' : 'Sign in and accept invite'}
          </PrimaryButton>
        </form>

        <p className="mt-5 text-center text-xs text-black/40">
          Wrong account?{' '}
          <Link to="/login" className="text-admin-accent hover:underline">
            Sign in elsewhere
          </Link>
        </p>
      </div>
    </div>
  )
}

function InviteStatusCard({
  title,
  body,
  action,
}: {
  title: string
  body: string
  action?: React.ReactNode
}) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-admin-bg p-6">
      <div className="w-full max-w-md rounded-2xl border border-admin-border bg-white p-8 text-center shadow-sm">
        <h1 className="text-xl font-semibold">{title}</h1>
        <p className="mt-3 text-sm text-black/55">{body}</p>
        <div className="mt-6 flex justify-center gap-3">
          {action ?? (
            <Link to="/login">
              <GhostButton>Sign in</GhostButton>
            </Link>
          )}
        </div>
      </div>
    </div>
  )
}
