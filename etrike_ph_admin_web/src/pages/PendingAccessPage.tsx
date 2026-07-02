import { useAuth } from '../hooks/useAuth'
import { GhostButton, PrimaryButton } from '../components/ui/AdminUi'

type Props = {
  variant?: 'pending' | 'revoked' | 'unregistered'
}

export function PendingAccessPage({ variant = 'pending' }: Props) {
  const { user, signOut, refreshOperator } = useAuth()
  const email = user?.email ?? 'unknown'

  const title =
    variant === 'revoked'
      ? 'Access revoked'
      : variant === 'unregistered'
        ? 'Access not granted'
        : 'Access pending approval'

  const message =
    variant === 'revoked'
      ? 'Your admin access has been revoked. Please reach out to the super admin if you believe this is a mistake.'
      : [
          'Please reach out to the admin for access.',
          'Your account must be approved before you can use the operator dashboard.',
        ].join(' ')

  return (
    <div className="flex min-h-screen items-center justify-center bg-admin-bg p-6">
      <div className="w-full max-w-lg rounded-2xl border border-admin-border bg-white p-8 text-center shadow-sm">
        <div
          className={[
            'mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full',
            'bg-amber-100 text-amber-700',
          ].join(' ')}
        >
          <span className="text-xl" aria-hidden>
            ⏳
          </span>
        </div>
        <h1 className="text-xl font-semibold">{title}</h1>
        <p className="mt-3 text-sm text-black/55">
          Signed in as <strong>{email}</strong>
        </p>
        <p className="mt-4 text-sm text-black/55">{message}</p>
        <div className="mt-6 flex justify-center gap-3">
          <PrimaryButton onClick={() => void refreshOperator()}>Check again</PrimaryButton>
          <GhostButton onClick={() => void signOut()}>Sign out</GhostButton>
        </div>
      </div>
    </div>
  )
}
