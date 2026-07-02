import { describe, expect, it, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import { PendingAccessPage } from '../pages/PendingAccessPage'

vi.mock('../hooks/useAuth', () => ({
  useAuth: () => ({
    user: { email: 'ops@example.com' },
    signOut: vi.fn(),
    refreshOperator: vi.fn(),
  }),
}))

describe('PendingAccessPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('shows pending message by default', () => {
    render(<PendingAccessPage />)
    expect(screen.getByText('Access pending approval')).toBeInTheDocument()
    expect(screen.getByText(/ops@example.com/)).toBeInTheDocument()
  })

  it('shows revoked variant', () => {
    render(<PendingAccessPage variant="revoked" />)
    expect(screen.getByText('Access revoked')).toBeInTheDocument()
  })
})
