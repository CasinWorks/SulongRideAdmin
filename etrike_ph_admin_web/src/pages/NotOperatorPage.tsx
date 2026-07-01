import { useAuth } from '../hooks/useAuth'
import { GhostButton, PrimaryButton } from '../components/ui/AdminUi'

export function NotOperatorPage() {
  const { user, signOut, refreshOperator } = useAuth()
  const email = user?.email ?? 'unknown'
  const uid = user?.id ?? '—'

  const sql = `insert into public.operators (id, email, full_name)
select id, email, 'Operator'
from auth.users
where email = '${email}'
on conflict (id) do update
  set email = excluded.email;`

  return (
    <div className="flex min-h-screen items-center justify-center bg-admin-bg p-6">
      <div className="w-full max-w-lg rounded-2xl border border-admin-border bg-white p-8 text-center shadow-sm">
        <h1 className="text-xl font-semibold">This account is not an operator</h1>
        <p className="mt-3 text-sm text-black/55">
          Signed in as <strong>{email}</strong>
          <br />
          User ID: <code className="text-xs">{uid}</code>
        </p>
        <p className="mt-4 text-sm text-black/55">
          In Supabase → SQL Editor, run the insert below, then tap Retry.
        </p>
        <pre className="mt-4 overflow-x-auto rounded-xl bg-admin-bg p-4 text-left text-xs text-admin-accent">
          {sql}
        </pre>
        <div className="mt-6 flex justify-center gap-3">
          <PrimaryButton onClick={() => void refreshOperator()}>Retry</PrimaryButton>
          <GhostButton onClick={() => void signOut()}>Sign out</GhostButton>
        </div>
      </div>
    </div>
  )
}
