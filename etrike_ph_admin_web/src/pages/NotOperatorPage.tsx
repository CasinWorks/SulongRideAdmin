import { useAuth } from '../hooks/useAuth'
import { operatorEmailDomain } from '../lib/operatorAuth'
import { GhostButton, PrimaryButton } from '../components/ui/AdminUi'

export function NotAllowedEmailPage() {
  const { user, signOut } = useAuth()
  const email = user?.email ?? 'unknown'
  const domain = operatorEmailDomain() ?? 'your organization'

  return (
    <div className="flex min-h-screen items-center justify-center bg-admin-bg p-6">
      <div className="w-full max-w-lg rounded-2xl border border-admin-border bg-white p-8 text-center shadow-sm">
        <h1 className="text-xl font-semibold">Email not allowed</h1>
        <p className="mt-3 text-sm text-black/55">
          Signed in as <strong>{email}</strong>, but this admin panel only accepts{' '}
          <strong>@{domain}</strong> accounts.
        </p>
        <p className="mt-4 text-sm text-black/55">
          Sign out and use an invited operator Gmail, or ask your admin to update access.
        </p>
        <div className="mt-6 flex justify-center">
          <GhostButton onClick={() => void signOut()}>Sign out</GhostButton>
        </div>
      </div>
    </div>
  )
}

/** Shown when a driver-app account tries to use the operator dashboard. */
export function DriverAccountPage() {
  const { user, signOut } = useAuth()
  const email = user?.email ?? 'unknown'

  return (
    <div className="flex min-h-screen items-center justify-center bg-admin-bg p-6">
      <div className="w-full max-w-lg rounded-2xl border border-admin-border bg-white p-8 text-center shadow-sm">
        <h1 className="text-xl font-semibold">Driver account not allowed</h1>
        <p className="mt-3 text-sm text-black/55">
          Signed in as <strong>{email}</strong>. This login is registered as a{' '}
          <strong>driver</strong> in the fleet app.
        </p>
        <p className="mt-4 text-sm text-black/55">
          The operator dashboard is invite-only. Use the driver mobile app, or ask a super admin
          to invite a separate operator account (different email) for admin access.
        </p>
        <div className="mt-6 flex justify-center">
          <GhostButton onClick={() => void signOut()}>Sign out</GhostButton>
        </div>
      </div>
    </div>
  )
}

/** Shown when the user is not invited (no row in operators). */
export function NotInvitedPage() {
  const { user, signOut, refreshOperator } = useAuth()
  const email = user?.email ?? 'unknown'
  const provider = (user?.app_metadata?.provider as string | undefined) ?? 'email'

  return (
    <div className="flex min-h-screen items-center justify-center bg-admin-bg p-6">
      <div className="w-full max-w-lg rounded-2xl border border-admin-border bg-white p-8 text-center shadow-sm">
        <h1 className="text-xl font-semibold">Not invited</h1>
        <p className="mt-3 text-sm text-black/55">
          Signed in as <strong>{email}</strong>
          {provider === 'google' ? ' (Google)' : ''}.
        </p>
        <p className="mt-4 text-sm text-black/55">
          Admin access is invite-only. Ask an admin to send you an invite link, open it, and sign
          in with the invited email.
        </p>
        <p className="mt-3 text-sm text-black/45">
          After you are invited, sign in again or tap Check again below.
        </p>
        <div className="mt-6 flex justify-center gap-3">
          <PrimaryButton onClick={() => void refreshOperator()}>Check again</PrimaryButton>
          <GhostButton onClick={() => void signOut()}>Sign out</GhostButton>
        </div>
      </div>
    </div>
  )
}
