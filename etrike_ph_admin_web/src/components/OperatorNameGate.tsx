import { useState, type ReactNode } from 'react'
import { useAuth } from '../hooks/useAuth'
import { needsOperatorName } from '../lib/displayName'
import { updateOperatorSelfName } from '../services/admin'
import { NameFormModal } from './NameFormModal'

type Props = {
  children: ReactNode
}

/** Prompts new operators to set a display name before using the app. */
export function OperatorNameGate({ children }: Props) {
  const { operator, user, refreshOperator } = useAuth()
  const [busy, setBusy] = useState(false)
  const [dismissed, setDismissed] = useState(false)

  if (!operator || !user) return <>{children}</>

  const mustSetName = needsOperatorName(operator.full_name, operator.email)
  const showModal = mustSetName && !dismissed

  async function handleSave(name: string) {
    setBusy(true)
    try {
      await updateOperatorSelfName(name)
      await refreshOperator()
      setDismissed(true)
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      {children}
      <NameFormModal
        open={showModal}
        required
        busy={busy}
        title="What should we call you?"
        description="This name appears in the sidebar and across the operator dashboard."
        initialName={operator.full_name?.trim() || user.email?.split('@')[0] || ''}
        onSave={handleSave}
      />
    </>
  )
}
