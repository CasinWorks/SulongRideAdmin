import { useAuth } from '../hooks/useAuth'
import { operatorAccessBannerMessage } from '../lib/operatorPermissions'

export function RoleAccessBanner() {
  const { operatorRole } = useAuth()
  const message = operatorAccessBannerMessage(operatorRole)
  if (!message) return null

  return (
    <div
      className="mb-4 rounded-xl border border-sky-200 bg-sky-50 px-4 py-3 text-sm text-sky-950"
      role="status"
    >
      <strong>Role access.</strong> {message}
    </div>
  )
}
